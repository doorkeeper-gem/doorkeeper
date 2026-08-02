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
        return false unless Doorkeeper.config.enable_secret_rotation?
        return true if secret_rotation_columns?

        warn_missing_secret_rotation_columns
        false
      end

      # Whether the columns a rotation writes are there, without asking
      # whether the option that writes them is on.
      #
      # The half of the check that ending a grace period goes on: turning
      # `enable_secret_rotation` off stops a retained secret authenticating
      # but does not remove it, so the row goes on holding a live credential
      # that comes back into service the moment the option does. Dropping it
      # must not require re-arming the feature for every application on the
      # server first, so +#clear_old_secret!+ asks this and +#rotate_secret!+
      # asks the one above.
      #
      # @return [Boolean]
      #
      def secret_rotation_columns?
        column_names.include?("old_secret") && column_names.include?("old_secret_created_at")
      end

      private

      # Enabling the option without running the migration is deliberately not
      # an error: client authentication carries on exactly as it did before.
      # But it is also entirely silent, so the first sign of it would be a
      # `SecretRotationNotEnabled` from whichever console session or job first
      # calls `#rotate_secret!`. Said once per process instead, here rather
      # than from a boot hook: the columns are read off the schema, which is a
      # database read, and a boot hook asking for them would open a connection
      # during tasks that have no database to open one to (`assets:precompile`
      # and friends) and wait through its retries before finding that out.
      # Here the schema has already been loaded by the caller's own lookup.
      #
      # Set before the write so that a logger raising cannot turn the warning
      # into one per authentication, and not synchronised: two threads racing
      # the first lookup cost a duplicate line, which is cheaper than a lock on
      # a path every client authentication takes.
      def warn_missing_secret_rotation_columns
        return if @secret_rotation_columns_warned
        return unless defined?(::Rails) && ::Rails.logger

        @secret_rotation_columns_warned = true
        ::Rails.logger.warn(
          "[DOORKEEPER] enable_secret_rotation is set, but #{name} has no " \
          "old_secret / old_secret_created_at columns: client authentication is unchanged and " \
          "Application#rotate_secret! raises SecretRotationNotEnabled. Run " \
          "`rails generate doorkeeper:secret_rotation` and apply the migration.",
        )
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

      # When matching the secret by comparer function, all is well.
      return true if secret_strategy.secret_matches?(input, secret)

      # When fallback lookup is enabled, ensure applications with plain secrets
      # can still be found, upgrading the stored secret to the active strategy
      # on a successful match.
      if fallback_secret_strategy&.secret_matches?(input, secret)
        self.class.upgrade_fallback_value(self, :secret, input)
        true
      else
        false
      end
    end
  end
end
