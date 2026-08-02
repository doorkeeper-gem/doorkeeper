# frozen_string_literal: true

module Doorkeeper::Orm::ActiveRecord::Mixins
  # Client secret rotation: the secret superseded by +#rotate_secret!+ is
  # retained in `old_secret` and keeps authenticating the client until
  # +#clear_old_secret!+ ends the grace period. Opening one requires the
  # `enable_secret_rotation` option and the columns the
  # `doorkeeper:secret_rotation` generator adds; ending one requires only the
  # columns, so that a server which has since turned the option off can still
  # drop what its last rotation retained.
  #
  # Kept in a file of its own rather than in the application mixin: what is
  # written here is a read-modify-write on a live credential under a row
  # lock, with a rollback repair on the way out. Those invariants are easier
  # to hold in view — and to change — when they are not interleaved with the
  # model's validations, associations and serialization.
  #
  # The comparison side of the feature — honouring the retained secret when
  # a client authenticates — belongs in +Doorkeeper::ApplicationMixin+, which
  # every ORM shares, because a stored secret is compared the same way
  # whichever one wrote it.
  module SecretRotation
    extend ActiveSupport::Concern

    # Replaces this application's secret, retaining the superseded one so
    # that clients still presenting it keep authenticating until the
    # application ends the grace period with +#clear_old_secret!+. Requires
    # the `enable_secret_rotation` option and the columns it needs. For a
    # replacement with no grace period, pass +revoke_old: true+ below: with
    # the feature on that is the only call that ends one, since
    # +#renew_secret+ writes the current secret alone and leaves whatever an
    # earlier rotation retained still authenticating.
    #
    # The superseded secret is carried over as *stored*: hashing strategies
    # draw a fresh salt on every write, so the plaintext is not available to
    # store again — and does not need to be, since both columns are written
    # and read back through the same strategy.
    #
    # Only one generation is retained, mirroring how `previous_refresh_token`
    # keeps a single generation of refresh tokens. Rotating twice in a row
    # therefore ends the first rotation's grace period early: the secret it
    # retained is replaced by the one the second rotation supersedes, and
    # clients that had not yet moved off it stop authenticating. A rotation
    # is meant to be followed by `#clear_old_secret!`, not by another
    # rotation.
    #
    # @param revoke_old [Boolean]
    #   drop the current secret instead of retaining it. For a secret
    #   believed to be compromised, which has to stop working now rather
    #   than at the end of a grace period.
    #
    # @return [String] new plain text secret value
    #
    def rotate_secret!(revoke_old: false)
      # Captured before the guard so that the rescue below restores it even
      # when nothing was attempted: a bare `raise` from the guard must not
      # cost an application the plaintext of the secret it already has.
      previous_raw_secret = @raw_secret

      # Set once the lock block is entered. Failures before that point —
      # the feature guard, `with_lock` refusing a record that carries
      # unsaved changes — happen before this method has written anything,
      # so there is nothing to roll back, and restoring anyway would
      # discard values the caller had assigned to these columns.
      locked = false

      begin
        ensure_secret_rotation_enabled!
        ensure_lockable!

        self.class.with_primary_role do
          # Read-modify-write on the row: the secret being retained is the
          # one currently stored, so two rotations racing without a lock
          # would let the later one overwrite a secret the earlier one had
          # already handed to a client — which would then never
          # authenticate. `with_lock` reloads under the lock, so the retained
          # value is the committed one even if this instance was loaded
          # before the other rotation.
          with_lock do
            locked = true

            # A blank `secret` joins `revoke_old` because there is
            # nothing to retain either way: a host schema that relaxed the
            # install migration's `null: false` can hold a public client
            # with no secret at all (see +#secret_required?+). Stamping the
            # timestamp regardless would open a grace period over an empty
            # `old_secret`, leaving the row saying a rotation is midway
            # through when nothing was carried over.
            # `renew_secret` below still writes one, as it always has, so
            # such a client comes out of a rotation holding a secret.
            if revoke_old || secret.blank?
              self.old_secret = nil
              self.old_secret_created_at = nil
            else
              self.old_secret = secret
              self.old_secret_created_at = Time.now.utc
            end

            renew_secret
            save!
          end
        end
      rescue StandardError
        undo_failed_rotation(locked, previous_raw_secret)
        raise
      end

      plaintext_secret
    end

    # Ends the grace period opened by the last rotation, dropping the
    # superseded secret. When that happens is left to the application — a
    # console, an admin action, a rake task, or a job driven by
    # +old_secret_created_at+: with no +secret_rotation_grace_period+
    # configured Doorkeeper expires nothing on its own, so an old secret
    # that is never cleared stays valid indefinitely.
    #
    # A configured deadline stops it authenticating when it passes
    # (+#old_secret_expired?+) but leaves the value where it is: dropping it
    # from the row is this method's, deadline or not. So does turning the
    # option off, and for the same reason this method asks only for the
    # columns: expiry is a comparison made when a client authenticates, so
    # lengthening the deadline, removing it, or setting `enable_secret_rotation`
    # again puts a retained secret straight back into service. Nothing but this
    # retires one for good, and needing the option to run it would mean
    # re-arming the feature for every application on the server in order to
    # clean up after one.
    #
    # Takes the row lock for the same reason +#rotate_secret!+ does, and
    # decides whether there is anything to clear under it: read outside the
    # lock, the answer describes whatever this instance was loaded with,
    # which a rotation committed since then has already made wrong in both
    # directions. As with a rotation, taking the lock requires a record free
    # of unsaved changes.
    #
    # Pass +retained_at:+ to make the clear conditional on the grace period
    # still being the one the caller looked at. A job selecting rows by an
    # expired +old_secret_created_at+ — which this feature invites, since
    # that column is what such a job has to go on — can otherwise be raced
    # by a fresh +#rotate_secret!+ between its query and this lock, and the
    # reload below would then hand it the *new* grace period to end,
    # cutting off the clients that rotation was opened for. With the
    # timestamp it observed, a row whose grace period changed underneath is
    # left alone and answers false. Omitted, the clear is unconditional:
    # what an admin ending a grace period by hand means is "whatever is
    # there now".
    #
    # @param retained_at [Time, nil] the +old_secret_created_at+ the caller
    #   decided on, or nil to clear whatever the row holds. Anything that is
    #   not a time raises +ArgumentError+ rather than answering false, which
    #   would be indistinguishable from another process having got there
    #   first.
    #
    # @return [Boolean] whether a grace period was there to end
    #
    def clear_old_secret!(retained_at: nil)
      ensure_secret_rotation_columns!
      ensure_comparable_retained_at!(retained_at)
      ensure_lockable!

      cleared = false

      # Same boundary as in #rotate_secret!: nothing is written before the
      # lock block runs, so a failure ahead of it leaves nothing to restore.
      locked = false

      self.class.with_primary_role do
        with_lock do
          locked = true

          # `with_lock` reloads, so `secret` is what is committed — which a
          # rotation running since this instance was loaded has already
          # replaced. The volatile plaintext is not reloaded with it, and
          # left alone it would have +#plaintext_secret+ hand out a secret
          # the row has moved on from — one this method is about to stop
          # authenticating altogether, since a superseded secret is exactly
          # what `old_secret` holds. Kept only while it still describes the
          # stored secret, the filter +#undo_failed_rotation+ applies after
          # its own reload and for the same reason.
          @raw_secret = restorable_raw_secret(@raw_secret)

          # Both columns decide, not `old_secret` alone: a row carrying a
          # timestamp with nothing behind it — written by something other
          # than +#rotate_secret!+ — reports a rotation midway through, and
          # keying the no-op on the secret would leave every run of a
          # cleanup job driven by `old_secret_created_at` reselecting it
          # without ever clearing it.
          next if old_secret.blank? && old_secret_created_at.blank?
          # Read under the lock, so the comparison is against what is
          # committed rather than what this instance was loaded with, and
          # compared as a time rather than as whatever the caller happened to
          # be holding: a `retained_at` that arrived through a job payload or
          # a form is a String, and comparing it as one answers false without
          # saying why — which the caller cannot tell apart from another
          # process having ended the grace period first.
          next if retained_at && old_secret_created_at != retained_at

          # Assignment and `save!`, the shape +#rotate_secret!+ uses, rather
          # than `update!`: `update!` wraps the assignment in a transaction
          # of its own, so the record is snapshotted while still clean and a
          # rollback that arrives after the write leaves it clean holding
          # the new values — the rescue below would then have nothing to put
          # back, and the instance would report a grace period the row still
          # has. Same statement, same validations, same callbacks; only the
          # nesting differs.
          self.old_secret = nil
          self.old_secret_created_at = nil
          save!
          cleared = true
        end
      end

      cleared
    rescue StandardError
      # Symmetric with #rotate_secret!: the row is rolled back, so the
      # instance must not be left claiming a grace period it still has, and
      # everything the write dirtied — `updated_at` included — goes back
      # with it. See that method's rescue for why the list is not named.
      restore_attributes if locked
      raise
    end

    private

    # +retained_at+ is the `old_secret_created_at` the caller read off a row,
    # so anything that is not a time is their mistake rather than a grace
    # period that moved. Said out loud instead of compared: a String — which
    # is what the value becomes on its way through a job payload or a form —
    # is never equal to a time, so the clear would answer false, and false is
    # what this method says when another process has already ended the grace
    # period. The caller cannot tell those apart.
    #
    # Coercing it instead would be worse than either: `#to_s` on a timestamp
    # drops the sub-second digits the column keeps, so the round trip
    # compares unequal and answers false all the same, only now with a
    # plausible-looking value to explain it.
    def ensure_comparable_retained_at!(retained_at)
      return if retained_at.nil? || retained_at.acts_like?(:time)

      raise ArgumentError,
            "retained_at must be the `old_secret_created_at` you decided on, " \
            "got #{retained_at.inspect}."
    end

    def ensure_secret_rotation_enabled!
      return if self.class.secret_rotation_enabled?

      raise Doorkeeper::Errors::SecretRotationNotEnabled, self.class.table_name
    end

    # The columns, without asking whether the option that writes them is on.
    # What #clear_old_secret! is gated on, because turning `enable_secret_rotation`
    # off does not clear what the last rotation retained: the row goes on
    # holding a live credential, one that authenticates again the moment the
    # option comes back. Ending that grace period is exactly the thing a
    # server must not have to re-arm the feature — for every application on
    # it, not just this one — in order to do.
    def ensure_secret_rotation_columns!
      return if self.class.secret_rotation_columns?

      raise Doorkeeper::Errors::SecretRotationNotEnabled, self.class.table_name
    end

    # `with_lock` gates both of its guarantees on +persisted?+ (Active
    # Record's +#lock!+ does): on a new record it takes no row lock and does
    # not refuse the caller's unsaved changes, so it degenerates to a bare
    # transaction. A rotation there would INSERT whatever else the caller had
    # assigned, and — where they had assigned a secret of their own — retain
    # that plaintext as `old_secret`, creating a row that is already midway
    # through a rotation nobody performed. Both APIs document the opposite,
    # so the case is refused rather than quietly redefined.
    #
    # +persisted?+ is also false for a destroyed record, which saving would
    # not bring back, so that one is told what is actually the matter.
    def ensure_lockable!
      return if persisted?

      remedy = destroyed? ? "the record has been destroyed" : "save the record first"

      raise ::ActiveRecord::RecordNotSaved.new(
        "client secret rotation needs a persisted #{self.class.name}; #{remedy}",
        self,
      )
    end

    # Puts the instance back after a rotation that did not complete.
    #
    # The row is rolled back, but Active Record leaves the in-memory
    # attributes as the failed write left them — an instance still holding
    # a secret that was never stored is a trap for any caller that rescues
    # and carries on. Everything the write dirtied is restored, and only
    # when the lock block actually ran. Naming the three secret columns was
    # too narrow: a failure landing after validation — a host `after_save`
    # raising, a deadlock, a value too long — has `save!` stamp `updated_at`
    # first, and Active Record's rollback marks it dirty against the
    # pre-transaction snapshot. Left behind, that one attribute makes every
    # later `with_lock` on this instance raise over unsaved changes, so
    # neither +#rotate_secret!+ nor +#clear_old_secret!+ could be retried on
    # it. Nothing of the caller's is discarded by restoring all of it:
    # +ensure_lockable!+ has refused an unpersisted record, and `lock!`
    # reloads a persisted one, so the instance was clean on the way in.
    #
    # Which plaintext still describes the stored secret depends on where
    # the failure happened. A rolled-back write leaves the previous secret
    # stored, and the previous plaintext describes it. But an exception
    # arriving after the commit — a host application's `after_commit`
    # callback raising — leaves the rotation written, the restore above a
    # no-op, and the plaintext this rotation generated as the only copy of
    # the committed secret; putting the previous one back would discard it.
    # Each candidate is kept only while it matches what is stored, so
    # whichever side of the commit the failure fell on, the plaintext that
    # survives is the one describing the row.
    #
    # None of that applies before the lock block runs: nothing was written,
    # the plaintext the caller came in with still describes the row, and
    # filtering it would compare it against whatever they had assigned to
    # `secret` and never saved — throwing away a good plaintext over a
    # value the row does not hold.
    def undo_failed_rotation(locked, previous_raw_secret)
      unless locked
        @raw_secret = previous_raw_secret
        return
      end

      restore_attributes
      @raw_secret = restorable_raw_secret(@raw_secret) ||
                    restorable_raw_secret(previous_raw_secret)
    end

    # The plaintext to keep after a failed rotation. `with_lock` reloads, so
    # the attributes restored on the way out are what was committed by then
    # — which a rotation racing this one may have replaced the secret in.
    # Putting the pre-lock plaintext back over that would have
    # +#plaintext_secret+ describe a secret the row no longer holds, so it
    # is kept only while it still matches what is stored. Otherwise nothing
    # here describes that secret, and an unknown plaintext is the honest
    # answer.
    #
    # The comparison honours the fallback strategy the way every other
    # comparison here does (see ApplicationMixin#stored_secret_matches?): a
    # restored legacy value the fallback still matches is the stored
    # credential, and the plaintext describing it survives with it.
    #
    # A row restored to no secret at all — a public client whose `secret`
    # column is nullable — leaves nothing for a plaintext to describe, and
    # nothing the strategies may be handed: their comparison raises on a
    # nil stored value, which would mask the error being raised through
    # here.
    def restorable_raw_secret(raw)
      return raw if raw.nil?
      return if secret.nil?
      return raw if secret_strategy.secret_matches?(raw, secret)
      return raw if fallback_secret_strategy&.secret_matches?(raw, secret)

      nil
    end
  end
end
