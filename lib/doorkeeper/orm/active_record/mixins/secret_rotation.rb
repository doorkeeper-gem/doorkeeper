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
      ensure_secret_rotation_enabled!
      ensure_lockable!

      self.class.with_primary_role do
        # Read-modify-write: without the lock two rotations racing would let
        # the later one overwrite a secret the earlier one already handed
        # out. `with_lock` reloads, so the retained value is the committed one.
        with_lock do
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
        end
      end

      plaintext_secret
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

    def ensure_secret_rotation_enabled!
      return if self.class.secret_rotation_enabled?

      raise Doorkeeper::Errors::SecretRotationNotEnabled, self.class.table_name
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
