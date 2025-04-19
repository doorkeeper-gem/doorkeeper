# frozen_string_literal: true

module Doorkeeper
  class Config
    # Doorkeeper configuration validator.
    #
    module Validations
      # Validates configuration options to be set properly.
      #
      def validate!
        validate_reuse_access_token_value
        validate_token_reuse_limit
        validate_secret_strategies
        validate_pkce_code_challenge_methods
        validate_custom_discovery_data
      end

      private

      # Determine whether +reuse_access_token+ and a non-restorable
      # +token_secret_strategy+ have both been activated.
      #
      # In that case, disable reuse_access_token value and warn the user.
      def validate_reuse_access_token_value
        strategy = token_secret_strategy
        return if !reuse_access_token || strategy.allows_restoring_secrets?

        ::Rails.logger.warn(
          "[DOORKEEPER] You have configured both reuse_access_token " \
          "AND '#{strategy}' strategy which cannot restore tokens. " \
          "This combination is unsupported. reuse_access_token will be disabled",
        )
        @reuse_access_token = false
      end

      # Validate that the provided strategies are valid for
      # tokens and applications
      def validate_secret_strategies
        token_secret_strategy.validate_for(:token)
        application_secret_strategy.validate_for(:application)
      end

      def validate_token_reuse_limit
        return if !reuse_access_token ||
                  (token_reuse_limit > 0 && token_reuse_limit <= 100)

        ::Rails.logger.warn(
          "[DOORKEEPER] You have configured an invalid value for token_reuse_limit option. " \
          "It will be set to default 100",
        )
        @token_reuse_limit = 100
      end

      def validate_pkce_code_challenge_methods
        return if pkce_code_challenge_methods.all? {|method| method =~ /^plain$|^S256$/ }

        ::Rails.logger.warn(
          "[DOORKEEPER] You have configured an invalid value for pkce_code_challenge_methods option. " \
          "It will be set to default ['plain', 'S256']",
        )

        @pkce_code_challenge_methods = ['plain', 'S256']
      end

      def validate_custom_discovery_data
        return if custom_discovery_data.is_a? Hash

        ::Rails.logger.warn(
          "[DOORKEEPER] You have configured an invalid value for custom_discovery_data option. " \
          "It must be a Hash, and will be overridden with an empty hash.",
        )

        @custom_discovery_data = {}
      end
    end
  end
end
