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
      # authenticating the client for a grace period: the
      # `enable_secret_rotation` option plus the `old_secret` and
      # `old_secret_created_at` columns. The columns are read rather than
      # assumed (as `pkce_supported?` does), so enabling the option without
      # the migration leaves authentication unchanged instead of raising on
      # every token request.
      #
      # @return [Boolean]
      #
      def secret_rotation_enabled?
        return false unless Doorkeeper.config.enable_secret_rotation?
        return true if secret_rotation_columns?

        warn_missing_secret_rotation_columns
        false
      end

      # Whether the rotation columns exist, without asking whether the option
      # is on. What +#clear_old_secret!+ is gated on: turning the option off
      # leaves a retained secret in the row, and dropping it must not require
      # re-arming the feature first.
      #
      # @return [Boolean]
      #
      def secret_rotation_columns?
        column_names.include?("old_secret") && column_names.include?("old_secret_created_at")
      end

      private

      # Once per process, from here rather than a boot hook: reading the
      # columns is a database read, which tasks like `assets:precompile`
      # have no database for. Set before the write so a raising logger
      # cannot repeat it on every authentication.
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
    # — or, with `enable_secret_rotation` on, the secret retained by the last
    # rotation while its grace period lasts (see +#old_secret_matches?+).
    #
    # @param input [#to_s] Plain secret provided by user
    #        (any object that responds to `#to_s`)
    #
    # @return [Boolean] Whether the given secret matches the stored secret
    #                of this application, or its retained old secret.
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

      # Both comparisons run and are combined afterwards: returning as soon
      # as the current secret matches would make a success cheaper than a
      # failure by one comparison, which under bcrypt dominates the request.
      match = stored_secret_matches?(input, :secret)
      old_match = old_secret_matches?(input)

      match || old_match
    end

    # Check whether the given plain text secret matches the secret superseded
    # by the last rotation (see +#rotate_secret!+).
    #
    # A comparison runs even when there is nothing retained: against the
    # current secret, with the result
    # discarded, so that whether this client is midway through a rotation
    # cannot be read off the response time. That holds whenever both columns
    # were written by the same strategy, which a rotation sees to (see the
    # Active Record mixin's #retain_secret); a `fallback:` strategy that
    # hashes leaves nothing to re-derive from, and the two columns then cost
    # different comparisons. Retire such a fallback before rotating under it.
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
      # An application with no secret is a public client, whose secret is
      # never checked; +#secret_matches?+ never reaches here for one.
      return false if secret.nil?

      matched =
        if rotated
          stored_secret_matches?(input.to_s, :old_secret)
        else
          # The dummy comparison must write nothing: with the upgrade left on,
          # a question about the superseded secret would rewrite the current one.
          stored_secret_matches?(input.to_s, :secret, upgrade: false)
        end

      # Exactly one comparison has run on every path.
      rotated && matched
    end

    private

    # Compare +input+ against the secret stored in +attribute+, honouring the
    # configured fallback strategy the same way the primary secret always has.
    #
    # @param input [String] Plain secret provided by user
    # @param attribute [Symbol] the secret attribute to compare against
    # @param upgrade [Boolean] whether a fallback match rewrites the stored
    #        value in the active strategy's format. Off for a comparison whose
    #        result is discarded (see +#old_secret_matches?+).
    #
    # @return [Boolean]
    #
    def stored_secret_matches?(input, attribute, upgrade: true)
      # Through the reader, so a host's own `secret` or `old_secret` reader is honoured.
      stored = attribute == :old_secret ? old_secret : secret

      # When matching the secret by comparer function, all is well.
      return true if secret_strategy.secret_matches?(input, stored)

      # When fallback lookup is enabled, ensure applications with plain secrets
      # can still be found, upgrading the stored secret to the active strategy
      # on a successful match.
      if fallback_secret_strategy&.secret_matches?(input, stored)
        self.class.upgrade_fallback_value(self, attribute, input) if upgrade
        true
      else
        false
      end
    end
  end
end
