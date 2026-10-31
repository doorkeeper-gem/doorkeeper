# frozen_string_literal: true

module Doorkeeper::Orm::ActiveRecord::Mixins
  # Client secret rotation: the secret superseded by a rotation is retained
  # in `old_secret` and keeps authenticating the client for a grace period.
  # The comparison side lives in +Doorkeeper::ApplicationMixin+, which every
  # ORM shares; this module holds what is Active Record's own.
  module SecretRotation
    extend ActiveSupport::Concern

    included do
      # A retained secret is a live credential, so both columns read as
      # [FILTERED] from #inspect. Declared on the model rather than added to
      # `config.filter_parameters`, which reaches every log line of the host
      # (see #792); SQL bind logging is filtered through the host's own list.
      self.filter_attributes += %i[old_secret old_secret_created_at]
    end

    # Replaces this application's secret, retaining the superseded one so that
    # clients still presenting it keep authenticating for a grace period.
    #
    # Only one generation is retained (as `previous_refresh_token` keeps one
    # generation of refresh tokens), so rotating twice ends the first grace
    # period early. The superseded secret is carried over as stored; a value
    # written by the `fallback:` strategy is re-derived under the active one
    # (see #retain_secret). +#renew_secret+ is unchanged: it writes the current
    # secret alone and leaves whatever an earlier rotation retained.
    #
    # @param revoke_old [Boolean] drop the current secret instead of retaining
    #   it: the replacement with no grace period, for a compromised secret.
    #
    # @return [String] new plain text secret value
    #
    def rotate_secret!(revoke_old: false)
      # Captured before the guards so that a refused call keeps the plaintext
      # the caller already had.
      previous_raw_secret = @raw_secret
      # The secret `save!` stored, so the rescue can tell a failure after the
      # COMMIT (host after_commit raising) from one before it.
      stored_secret = nil
      # Nothing is written before the lock block, so a failure ahead of it
      # must not discard values the caller assigned.
      locked = false

      begin
        ensure_secret_rotation_enabled!
        ensure_lockable!

        self.class.with_primary_role do
          # Read-modify-write: without the lock two rotations racing would let
          # the later one overwrite a secret the earlier one already handed
          # out. `with_lock` reloads, so the retained value is the committed one.
          with_lock do
            locked = true

            # A blank `secret` (a public client on a schema that relaxed
            # `null: false`) has nothing to retain; stamping the timestamp
            # anyway would report a rotation midway through nothing.
            if revoke_old || secret.blank?
              self.old_secret = nil
              self.old_secret_created_at = nil
            else
              retain_secret
              self.old_secret_created_at = Time.now.utc
            end

            renew_secret
            save!
            stored_secret = secret
          end
        end
      rescue StandardError
        undo_failed_rotation(locked, previous_raw_secret, stored_secret)
        raise
      end

      plaintext_secret
    end

    # Ends the grace period opened by the last rotation, dropping the
    # superseded secret. Needs the columns, not the option: turning
    # `enable_secret_rotation` off leaves the retained secret in the row, and
    # it authenticates again the moment the option returns.
    #
    # Decides whether there is anything to clear under the row lock: read
    # outside it, the answer describes whatever this instance was loaded with.
    #
    # @param retained_at [Time, nil] the +old_secret_created_at+ the caller
    #   decided on. A job selecting rows by that column can be raced by a fresh
    #   rotation between its query and this lock; with the timestamp it saw, a
    #   row whose grace period changed underneath is left alone and answers
    #   false. Nil clears whatever the row holds. Anything that is not a time
    #   raises +ArgumentError+ rather than answering false, which the caller
    #   could not tell apart from another process having got there first.
    #
    # @return [Boolean] whether a grace period was there to end
    #
    def clear_old_secret!(retained_at: nil)
      ensure_secret_rotation_columns!
      ensure_comparable_retained_at!(retained_at)
      ensure_lockable!

      cleared = false
      locked = false

      self.class.with_primary_role do
        with_lock do
          locked = true

          # `with_lock` reloaded `secret` but not the volatile plaintext; keep
          # it only while it still describes the stored secret.
          @raw_secret = restorable_raw_secret(@raw_secret)

          # Both columns decide: a timestamp with nothing behind it would
          # otherwise be reselected by a cleanup job forever.
          next if old_secret.blank? && old_secret_created_at.blank?
          next if retained_at && old_secret_created_at != retained_at

          # Assignment + `save!` rather than `update!`: the latter snapshots
          # the record inside its own transaction, so a rollback arriving
          # after the write would leave nothing for the rescue to restore.
          self.old_secret = nil
          self.old_secret_created_at = nil
          save!
          cleared = true
        end
      end

      cleared
    rescue StandardError
      undo_failed_clear(locked, cleared)
      raise
    end

    # Serializes the application attributes minus the ones a rotation writes
    # (see #withhold_rotation_attributes). Every ActiveModel serialization path
    # (#as_json, #to_json) runs through here. A caller naming +old_secret+ in
    # +methods:+ is still answered, as ActiveModel documents.
    #
    # @param options [Hash, nil] serialization options
    #
    # @return [Hash] entity attributes
    #
    def serializable_hash(options = nil)
      super(withhold_rotation_attributes(options))
    end

    private

    # A String (what a time becomes through a job payload or a form) is never
    # equal to a time, so comparing it would answer false, indistinguishable
    # from another process having ended the grace period first. Coercing it
    # is no better: `#to_s` drops the sub-second digits the column keeps.
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

    def ensure_secret_rotation_columns!
      return if self.class.secret_rotation_columns?

      raise Doorkeeper::Errors::SecretRotationNotEnabled.new(self.class.table_name, columns_only: true)
    end

    # `with_lock` takes no row lock on an unpersisted record and does not
    # refuse its unsaved changes, so a rotation there would INSERT whatever
    # the caller had assigned and retain their plaintext as `old_secret`.
    def ensure_lockable!
      return if persisted?

      remedy = destroyed? ? "the record has been destroyed" : "save the record first"

      raise ::ActiveRecord::RecordNotSaved.new(
        "client secret rotation needs a persisted #{self.class.name}; #{remedy}",
        self,
      )
    end

    # Puts the instance back after a rotation that did not complete: Active
    # Record rolls the row back but leaves the in-memory attributes as the
    # failed write left them. Everything dirtied is restored (`updated_at`
    # included, or every later `with_lock` on this instance would refuse the
    # unsaved change), and only when the lock block ran.
    #
    # The plaintext kept is whichever one still describes the stored secret:
    # the previous one after a rollback, this rotation's after a failure past
    # the COMMIT. A COMMIT lost to +ActiveRecord::ConnectionFailed+ (Rails
    # 7.1+ invalidates the transaction without rolling the record back) leaves
    # the instance claiming a secret the row never took, so the row is reloaded
    # from the primary in that case.
    #
    # @return [Boolean] whether the rotation that stored +stored_secret+ is
    #   the one the row holds (see #rotation_committed?)
    def undo_failed_rotation(locked, previous_raw_secret, stored_secret)
      unless locked
        @raw_secret = previous_raw_secret
        return false
      end

      committed = rotation_committed?(stored_secret)
      restore_attributes
      self.class.with_primary_role { reload } if !committed && !stored_secret.nil? && secret == stored_secret
      @raw_secret = restorable_raw_secret(@raw_secret) ||
                    restorable_raw_secret(previous_raw_secret)
      committed
    end

    # Whether the rotation that stored +stored_secret+ is the one the row
    # holds, read off the row on the primary: after a COMMIT lost to
    # +ActiveRecord::ConnectionFailed+ the instance looks committed while the
    # row most likely is not. A row gone in the meantime answers false.
    def rotation_committed?(stored_secret)
      return false if stored_secret.nil?

      self.class.with_primary_role do
        self.class.unscoped.find(id).secret == stored_secret
      end
    rescue ActiveRecord::RecordNotFound
      false
    end

    # Carries the stored secret into `old_secret` as it is, unless the fallback
    # strategy wrote it and can give the plaintext back: then it is re-derived
    # under the active strategy, so that a `fallback: :plain` secret does not
    # sit in `old_secret` in plain text for the grace period, and so that both
    # columns cost the same comparison (see ApplicationMixin#old_secret_matches?).
    #
    # Written through +store_secret+, as +#renew_secret+ does, so a strategy
    # that wraps what it stores keeps authenticating the retained secret.
    def retain_secret
      plain_secret = fallback_plaintext_to_re_derive

      if plain_secret
        secret_strategy.store_secret(self, :old_secret, plain_secret)
      else
        self.old_secret = secret
      end
    end

    def fallback_plaintext_to_re_derive
      return if recognized_by_active_strategy?(secret)
      return unless fallback_secret_strategy&.allows_restoring_secrets?

      fallback_secret_strategy.restore_secret(self, :secret).presence
    end

    # A strategy is duck typed everywhere else (Validations asks only for
    # +validate_for+), so one without the predicate is read as Base answers:
    # true, which retains the value as stored.
    def recognized_by_active_strategy?(stored)
      return true unless secret_strategy.respond_to?(:recognizes_stored_secret?)

      secret_strategy.recognizes_stored_secret?(stored)
    end

    # Puts the instance back after a clear that did not complete: Active
    # Record rolls the row back but leaves the in-memory attributes as the
    # failed write left them, and only when the lock block ran. A COMMIT lost
    # to +ActiveRecord::ConnectionFailed+ (Rails 7.1+ invalidates the
    # transaction without rolling the record back) leaves the record clean
    # with the columns cleared while the row still holds the retained secret,
    # so the row is reloaded from the primary in that case.
    def undo_failed_clear(locked, written)
      return unless locked

      restore_attributes
      return unless written && old_secret.blank? && old_secret_created_at.blank?

      self.class.with_primary_role { reload }
    end

    # The plaintext to keep: only while it still matches the stored secret,
    # which a rotation racing this one may have replaced. A row with no secret
    # (a nullable `secret` column) leaves nothing to describe, and the
    # strategies raise on a nil stored value.
    def restorable_raw_secret(raw)
      return raw if raw.nil?
      return if secret.nil?
      return raw if secret_strategy.secret_matches?(raw, secret)
      return raw if fallback_secret_strategy&.secret_matches?(raw, secret)

      nil
    end

    # Expressed against `only` as well as `except` because ActiveModel honours
    # one or the other, never both. `old_secret_created_at` goes with the
    # secret: on its own it reports that a rotation is midway through.
    def withhold_rotation_attributes(options)
      opts = options.try(:dup) || {}
      withheld = %w[old_secret old_secret_created_at]

      if opts[:only]
        opts[:only] = Array(opts[:only]).map(&:to_s) - withheld
      else
        opts[:except] = Array(opts[:except]).map(&:to_s) | withheld
      end

      opts
    end
  end
end
