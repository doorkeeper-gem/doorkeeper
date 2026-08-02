# frozen_string_literal: true

module Doorkeeper
  module ApplicationMixin
    extend ActiveSupport::Concern

    include OAuth::Helpers
    include Models::Concerns::WriteToPrimary
    include Models::Orderable
    include Models::SecretStorable
    include Models::Scopes

    # :nodoc
    module ClassMethods
      # Returns an instance of the Doorkeeper::Application with
      # specific UID and secret.
      #
      # Public/Non-confidential applications will only find by uid if secret is
      # blank.
      #
      # @param uid [#to_s] UID (any object that responds to `#to_s`)
      # @param secret [#to_s] secret (any object that responds to `#to_s`)
      #
      # @return [Doorkeeper::Application, nil]
      #   Application instance or nil if there is no record with such credentials
      #
      def by_uid_and_secret(uid, secret)
        app = by_uid(uid)
        return unless app
        return app if secret.blank? && !app.confidential?

        app if app.secret_matches?(secret)
      end

      # Returns an instance of the Doorkeeper::Application with specific UID.
      #
      # @param uid [#to_s] UID (any object that responds to `#to_s`)
      #
      # @return [Doorkeeper::Application, nil] Application instance or nil
      #   if there is no record with such UID
      #
      def by_uid(uid)
        find_by(uid: uid.to_s)
      end

      ##
      # Determines the secret storing transformer
      # Unless configured otherwise, uses the plain secret strategy
      def secret_strategy
        ::Doorkeeper.config.application_secret_strategy
      end

      ##
      # Determine the fallback storing strategy
      # Unless configured, there will be no fallback
      def fallback_secret_strategy
        ::Doorkeeper.config.application_secret_fallback_strategy
      end

      # Whether a superseded client secret is retained and keeps
      # authenticating the client for a grace period.
      #
      # Both halves are required: the `enable_secret_rotation` option opts the
      # server in, and the `old_secret` / `old_secret_created_at` columns are
      # where the superseded secret and the date it was retained live. Reading
      # the columns rather than assuming them (as `pkce_supported?` does for
      # `code_challenge`) means enabling the option without running the
      # migration leaves authentication behaving exactly as it did before,
      # instead of raising on every token request. Both are checked because a
      # rotation writes both: a half-applied migration is no more usable than
      # none at all, and failing the check is how it stays a no-op rather
      # than an error on the first `#rotate_secret!`.
      #
      # @return [Boolean]
      #
      def secret_rotation_enabled?
        Doorkeeper.config.enable_secret_rotation? &&
          column_names.include?("old_secret") &&
          column_names.include?("old_secret_created_at")
      end
    end

    # Set an application's valid redirect URIs.
    #
    # @param uris [String, Array<String>] Newline-separated string or array the URI(s)
    #
    # @return [String] The redirect URI(s) separated by newlines.
    #
    def redirect_uri=(uris)
      super(uris.is_a?(Array) ? uris.join("\n") : uris)
    end

    # Check whether the given plain text secret matches our stored secret
    #
    # @param input [#to_s] Plain secret provided by user
    #        (any object that responds to `#to_s`)
    #
    # @return [Boolean] Whether the given secret matches the stored secret
    #                of this application.
    #
    # @note When the secret matches only via the fallback strategy, the stored
    #       secret is upgraded to the active strategy as a side-effect (mirrors
    #       the find_by_plaintext_token -> find_by_fallback_token pattern).
    #
    def secret_matches?(input)
      # return false if either is nil, since secure_compare depends on strings
      # but Application secrets MAY be nil depending on confidentiality.
      return false if input.nil? || secret.nil?

      input = input.to_s

      return stored_secret_matches?(input, :secret) unless self.class.secret_rotation_enabled?

      # Both comparisons are performed and only then combined. Returning as
      # soon as the current secret matches would make a successful
      # authentication measurably cheaper than a failed one by exactly the cost
      # of one comparison — which under bcrypt is the dominant cost of the
      # request — so the shape of the work stays the same either way.
      match = stored_secret_matches?(input, :secret)
      old_match = old_secret_matches?(input)

      # Reported only when the old secret is what actually let the client in,
      # so that an application can tell whether anyone still depends on it
      # before ending the grace period. This runs on a successful
      # authentication only — a caller that cannot produce either secret never
      # reaches it, so it adds no signal an attacker can measure.
      Doorkeeper.config.after_old_secret_used.call(self) if old_match && !match

      match || old_match
    end

    # Check whether the given plain text secret matches the secret superseded
    # by the last rotation (see +#rotate_secret!+).
    #
    # A comparison runs even when no old secret is stored — against the current
    # secret, with the result discarded — so that whether this client is midway
    # through a rotation cannot be read off how long the endpoint took to
    # answer. The dummy comparison is deliberately made against a real stored
    # secret rather than a constant, so that it costs what a genuine comparison
    # costs whenever both columns were written by the same strategy. It does
    # not equalise a `secret` and an `old_secret` stored in *different*
    # formats, which the fallback strategy allows — see #old_secret_expired?
    # for the other half of that story.
    #
    # @param input [#to_s] Plain secret provided by user
    #        (any object that responds to `#to_s`)
    #
    # @return [Boolean] Whether the given secret matches the old secret
    #                of this application.
    #
    def old_secret_matches?(input)
      return false if input.nil? || !self.class.secret_rotation_enabled?

      rotated = old_secret.present?
      # Nothing to compare against, and nothing to hide either: an application
      # with no secret at all is a public client, whose secret is never checked.
      return false if !rotated && secret.nil?

      matched = stored_secret_matches?(input.to_s, rotated ? :old_secret : :secret)
      # Evaluated unconditionally, and only combined afterwards: `matched` has
      # already been computed, so discarding it costs the same as honouring it.
      expired = old_secret_expired?

      rotated && matched && !expired
    end

    # Whether the retained secret has outlived the configured
    # `secret_rotation_grace_period`. Always false when no grace period is
    # configured, which is the default: the grace period then ends only when
    # the application calls +#clear_old_secret!+. Also false when nothing is
    # retained — an application that never rotated has no grace period to
    # outlive.
    #
    # An old secret with no +old_secret_created_at+ is treated as expired
    # rather than as ageless. Every rotation records the timestamp, so a
    # missing one means the column was written by something other than
    # +#rotate_secret!+ — and honouring a deadline nobody can date would leave
    # exactly the indefinitely-valid secret the option was configured to
    # prevent.
    #
    # Expiring an old secret stops it authenticating; it does not remove it.
    # Use +#clear_old_secret!+ for that.
    #
    # @return [Boolean]
    #
    def old_secret_expired?
      grace_period = Doorkeeper.config.secret_rotation_grace_period
      return false if grace_period.nil? || old_secret.blank?
      return true if old_secret_created_at.blank?

      old_secret_created_at + grace_period < Time.now.utc
    end

    private

    # Compare +input+ against the secret stored in +attribute+, honouring the
    # configured fallback strategy the same way the primary secret always has.
    #
    # @param input [String] Plain secret provided by user
    # @param attribute [Symbol] the secret attribute to compare against
    #
    # @return [Boolean]
    #
    def stored_secret_matches?(input, attribute)
      stored = public_send(attribute)

      # When matching the secret by comparer function, all is well.
      return true if secret_strategy.secret_matches?(input, stored)

      # When fallback lookup is enabled, ensure applications with plain secrets
      # can still be found, upgrading the stored secret to the active strategy
      # on a successful match.
      if fallback_secret_strategy&.secret_matches?(input, stored)
        self.class.upgrade_fallback_value(self, attribute, input)
        true
      else
        false
      end
    end
  end
end
