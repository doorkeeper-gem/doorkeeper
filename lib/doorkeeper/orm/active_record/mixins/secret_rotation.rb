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
  # lock, with a rollback repair on the way out and a revocation sweep that
  # has to run after the commit for the lock order to stay consistent with
  # the one token requests take. Those invariants are easier to hold in view
  # — and to change — when they are not interleaved with the model's
  # validations, associations and serialization.
  #
  # The comparison side of the feature is not here: it lives in
  # +Doorkeeper::ApplicationMixin+, which every ORM shares, because a stored
  # secret is compared the same way whichever one wrote it.
  module SecretRotation
    extend ActiveSupport::Concern

    included do
      # A retained secret is a live credential — it authenticates the client
      # exactly as `secret` does — and plain text under the default strategy,
      # and the timestamp beside it says a client is midway through a
      # rotation. Named on the model, which is what Active Record matches
      # against column names, so both read as [FILTERED] from `#inspect`.
      # That is as far as a model's own list reaches: ActiveRecord's log
      # subscriber filters the bind values it logs through
      # `ActiveRecord::Base.inspection_filter` and never the model's, so
      # redacting those is the host application's to ask for -- README says
      # how. Not added to
      # `config.filter_parameters`, which reaches every model and every log
      # line in the host application: neither is the name of a request
      # parameter Doorkeeper accepts, and `token` was in that list once and
      # was taken back out for exactly that reason (#792).
      self.filter_attributes += %i[old_secret old_secret_created_at]
    end

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
    # and read back through the same strategy. The exception is a value the
    # active strategy does not recognise as its own, which is to say one a
    # `fallback:` strategy wrote: where that fallback can restore the
    # plaintext, the secret is re-derived under the active strategy as it is
    # retained, so that a rotation does not leave the plain text of a
    # `fallback: :plain` secret sitting in `old_secret`. See
    # +#retainable_secret+.
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
    # @param revoke_tokens [Boolean]
    #   additionally revoke this application's unredeemed authorization
    #   codes, which the current secret is enough to redeem, and the access
    #   tokens already issued to it. Revoking those tokens is precautionary
    #   — a secret does not hand out a token issued to someone else — except
    #   under +reuse_access_token+, where a client_credentials request made
    #   with that secret is answered with the token the grant already holds.
    #   The revocation runs once the rotation has committed; should it
    #   fail, the error is raised with the new secret already stored and
    #   still readable through +#plaintext_secret+ on this instance, and
    #   +#revoke_issued_credentials!+ can be retried on its own. Refused
    #   inside an open transaction (+Errors::SecretRotationInTransaction+),
    #   which would hold the rotation's row lock past this method: rotate
    #   without it there and revoke once the transaction has committed.
    #
    # @return [String] new plain text secret value
    #
    def rotate_secret!(revoke_old: false, revoke_tokens: false)
      # Captured before the guard so that the rescue below restores it even
      # when nothing was attempted: a bare `raise` from the guard must not
      # cost an application the plaintext of the secret it already has.
      previous_raw_secret = @raw_secret

      # Set once the row has been written. A host `after_commit` callback
      # raising lands in the rescue below on the other side of the commit —
      # the rotation is stored, and with revoke_tokens: the credentials the
      # superseded secret can still be exchanged for have to go with it,
      # error or no error. A COMMIT that fails after this point would have
      # the sweep run for a rotation that never landed, which costs the
      # client its tokens and no more; the other way round leaves a secret
      # its owner asked to revoke still minting them.
      written = false

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
          # Asked here, once the writer is the selected connection: the
          # transaction that matters is the one `with_lock` below would
          # join, and before the role switch the selected connection may be
          # a replica's, with no transaction open on it at all.
          ensure_revocation_can_follow_commit! if revoke_tokens

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
            # `old_secret` — one +#old_secret_expired?+ never expires and
            # +#old_secret_matches?+ never honours — leaving the row saying
            # a rotation is midway through when nothing was carried over.
            if revoke_old || secret.blank?
              self.old_secret = nil
              self.old_secret_created_at = nil
            else
              self.old_secret = retainable_secret
              self.old_secret_created_at = Time.now.utc
            end

            renew_secret
            save!
            written = true
          end
        end
      rescue StandardError
        undo_failed_rotation(locked, previous_raw_secret)
        # Runs before the re-raise so that a rotation that committed does
        # not keep its tokens. If the sweep itself fails, that failure is
        # what the caller sees, with the error that got us here as its
        # `cause` — neither is worth hiding.
        revoke_issued_credentials! if revoke_tokens && written
        raise
      end

      # Runs once the rotation has committed and the row lock is released —
      # see #revoke_issued_credentials! for why it cannot run under the lock.
      # That holds because `with_lock` opened the transaction: one it would
      # have joined was refused above, since the lock would then outlive
      # this method.
      # Outside the rescue above on purpose: the new secret is stored by
      # now, so a failure here must not roll the instance back to the old
      # one or discard the plaintext the caller still has to hand out —
      # `#plaintext_secret` keeps it through the raise.
      revoke_issued_credentials! if revoke_tokens

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

    # Revokes what a secret of this application could still be exchanged
    # for: its unrevoked access tokens and unredeemed authorization codes.
    # What +#rotate_secret!+ runs for +revoke_tokens: true+, kept separate
    # so that it can be retried on its own if that step fails — it is
    # idempotent, and a failure there leaves the rotation committed with
    # the new secret still readable through +#plaintext_secret+.
    # Access grants are included because an unredeemed authorization code is
    # exchanged with the client secret (RFC 6749 §4.1.3): leaving the codes
    # alive would hand back an access token minted after the revocation.
    #
    # Already-revoked records are left untouched so their original
    # `revoked_at` survives.
    #
    # Deliberately not run inside the rotation's row lock. A token request
    # locks its grant or refresh token first and then inserts a token, and
    # that insert takes a share lock on the application row for the foreign
    # key check. Revoking child rows while holding `FOR UPDATE` on the
    # application reverses that order, and the two deadlock — aborting
    # either the rotation or the token request. Running after the commit
    # keeps the lock order consistent, at the cost of a request that
    # authenticated before the rotation committed possibly finishing after
    # this sweep: a token it minted then is not revoked.
    #
    # @return [void]
    #
    def revoke_issued_credentials!
      now = Time.now.utc

      self.class.with_primary_role do
        revoke_unrevoked(access_tokens, now)
        revoke_unrevoked(access_grants, now)
      end
    end

    # Serializes the application attributes minus the ones a rotation
    # writes (see #withhold_rotation_attributes). This is the boundary
    # every ActiveModel serialization path shares — #as_json and #to_json
    # run through it — and a public entry point of its own, which would
    # otherwise hand out every attribute by default.
    #
    # It is the default that is changed, not a guarantee that is added:
    # +methods:+ appends a reader after +only+/+except+ have been applied,
    # as ActiveModel documents, so a caller naming +old_secret+ there is
    # answered. What this stops is every view that does not name it — the
    # ones that ask for all attributes, +only:+ included.
    #
    # @param options [Hash, nil] serialization options
    #
    # @return [Hash] entity attributes
    #
    def serializable_hash(options = nil)
      super(withhold_rotation_attributes(options))
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

    # `with_lock` joins a joinable transaction that is already open, and the
    # row lock it takes is then held until that transaction commits — past
    # the point where #revoke_issued_credentials! would run, recreating the
    # lock-order inversion it is kept out of the lock to avoid. So the
    # combination is refused up front, before anything is written. Meant to
    # be called with the writing role selected (see the call in
    # #rotate_secret!), so that the connection consulted is the one the
    # lock would be taken on.
    #
    # Deferring the sweep to that commit instead would be the other answer,
    # and it is not available: `ActiveRecord.after_all_transactions_commit`
    # arrived in Rails 7.2, and Doorkeeper supports 7.0. It would also not
    # be the answer it looks like — a transactional test rolls its outer
    # transaction back rather than committing it, so a deferred sweep would
    # silently never run there, which is worse than saying so.
    #
    # A non-joinable transaction is deliberately let through, even though
    # it is not harmless — `with_lock` nests in a savepoint there, and on
    # PostgreSQL the row lock still lives until the outer commit, sweep
    # included. Refusing it (asking `transaction_open?` rather than
    # `joinable?`) is worse: Rails' transactional tests and DatabaseCleaner's
    # transaction strategy wrap every example in exactly such a transaction,
    # so this method would raise in every example that rotates with
    # `revoke_tokens:` — this gem's own included, and every host
    # application's. `joinable: false` is the option Rails opens its own
    # fixture and `console --sandbox` transactions with, and a caller
    # passing it has said that nothing may join theirs — sweep timing
    # included. One that has not can rotate without `revoke_tokens:` and
    # call #revoke_issued_credentials! after its own commit, which is what
    # SecretRotationInTransaction says.
    #
    def ensure_revocation_can_follow_commit!
      return unless self.class.connection.current_transaction.joinable?

      raise Doorkeeper::Errors::SecretRotationInTransaction
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

    # The value to carry into `old_secret`: the stored secret as it is,
    # unless it was written by the fallback strategy rather than the active
    # one, in which case it is re-derived under the active strategy first.
    #
    # A fallback strategy exists so that secrets stored under a previous
    # strategy keep working until something rewrites them, and until this
    # they were carried into `old_secret` in that previous format. Two
    # things followed from that. The plaintext of a `fallback: :plain`
    # secret outlived the very rotation that replaced it, sitting in
    # `old_secret` for the length of the grace period on a row whose
    # `secret` is now hashed. And the retained secret cost a different
    # comparison from the current one, which is what
    # ApplicationMixin#old_secret_matches? equalises by comparing against
    # `secret` when there is nothing retained: a bcrypt comparison against a
    # plain `old_secret` is refused for its shape before any work factor
    # applies, so a rotated application answered measurably faster than an
    # unrotated one -- to anyone, holding no secret at all.
    #
    # Re-deriving needs the plaintext, which only a restorable fallback
    # strategy has (`:plain` is the one Doorkeeper ships). Against a
    # fallback that hashes, there is nothing to re-derive from and the value
    # is carried over as stored, as it always was.
    #
    # +recognizes_stored_secret?+ answers +true+ by default, so a custom
    # strategy that does not override it retains as stored as well: only a
    # strategy that can tell its own output apart from the fallback's takes
    # this path, and misreading a value it did write would replace a working
    # retained secret with the hash of its own hash.
    def retainable_secret
      return secret if recognized_by_active_strategy?(secret)
      return secret unless fallback_secret_strategy&.allows_restoring_secrets?

      plain_secret = fallback_secret_strategy.restore_secret(self, :secret)
      return secret if plain_secret.blank?

      secret_strategy.transform_secret(plain_secret)
    end

    # Whether the active strategy claims the stored value as its own.
    #
    # +recognizes_stored_secret?+ is new, and a secret strategy is duck typed
    # everywhere else it is used: +Validations#validate_secret_strategies+
    # asks a configured one for +validate_for+ and nothing more, so a strategy
    # that does not subclass +SecretStoring::Base+ has never had to define
    # anything it did not choose to. One is answered here the way Base answers
    # — true — which is the answer that changes nothing: the stored value is
    # retained as it is, exactly as a rotation retained it before this
    # predicate existed.
    def recognized_by_active_strategy?(stored)
      return true unless secret_strategy.respond_to?(:recognizes_stored_secret?)

      secret_strategy.recognizes_stored_secret?(stored)
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

    # Everything that still authenticates, which is not the same as
    # everything whose `revoked_at` is NULL: +Revocable#revoked?+ reads a
    # timestamp in the future as not revoked yet, so a host scheduling a
    # revocation ahead of time holds rows that are live and dated. A
    # rotation asked to revoke has to reach those too. Rows already revoked
    # keep the timestamp they have — moving it forward would rewrite when
    # they stopped working.
    def revoke_unrevoked(relation, now)
      table = relation.arel_table

      unrevoked = table[:revoked_at].eq(nil).or(table[:revoked_at].gt(now))

      relation.where(unrevoked).update_all(revoked_at: now)
    end

    # Removes the columns a rotation writes from serialization options.
    #
    # The retained secret is a live credential — it authenticates the client
    # exactly as `secret` does — so it must not be handed out anywhere, and
    # #serializable_hash (the owner view of #as_json included) would
    # otherwise serialize every attribute. `secret` is surfaced there
    # deliberately, through #read_attribute_for_serialization; nothing
    # surfaces this one.
    # `old_secret_created_at` goes with it: on its own it still reports that
    # a client is midway through a rotation.
    #
    # Expressed against `only` as well as `except` because ActiveModel
    # honours one or the other and never both — an explicit
    # `only: [:old_secret]` would walk straight past an exclusion written
    # only as `except`. The `only` branch mirrors ActiveModel's own test
    # (any non-nil value selects that path, including an empty array).
    #
    # An explicit `methods:` option still appends whatever the caller
    # names — ActiveModel applies it after the `only`/`except` filtering.
    # That escape hatch is left alone on purpose: both branches already
    # honour it for `secret` itself, and a host app naming an attribute
    # there is asking for the value, same as calling the reader directly.
    #
    # @param options [Hash] serialization options
    #
    # @return [Hash] the options with the rotation columns removed
    #
    def withhold_rotation_attributes(options)
      opts = options.try(:dup) || {}
      withheld = %w[old_secret old_secret_created_at]

      if opts[:only]
        opts[:only] = Array.wrap(opts[:only]).map(&:to_s) - withheld
      else
        opts[:except] = Array.wrap(opts[:except]).map(&:to_s) | withheld
      end

      opts
    end
  end
end
