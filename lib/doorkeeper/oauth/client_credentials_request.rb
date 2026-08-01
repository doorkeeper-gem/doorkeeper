# frozen_string_literal: true

module Doorkeeper
  module OAuth
    class ClientCredentialsRequest < BaseRequest
      validate :resource_indicators, error: Errors::InvalidTarget

      attr_reader :client, :original_scopes, :parameters, :response

      alias error_response response

      def initialize(server, client, parameters = {})
        super()
        @client = client
        @server = server
        @response = nil
        @grant_type = Doorkeeper::OAuth::CLIENT_CREDENTIALS
        @original_scopes = parameters[:scope]
        @raw_resource_indicators = parameters[:resource]
        @parameters = parameters.except(:scope, :resource)
      end

      def access_token
        issuer.token
      end

      def error
        @error || issuer.error
      end

      def issuer
        @issuer ||= ClientCredentials::Issuer.new(
          server,
          ClientCredentials::Validator.new(server, self),
        )
      end

      # The declared validations (DPoP proof, resource indicators) run first and
      # short-circuit issuance: a request that fails one of them must never
      # reach the creator.
      def validate
        super
        return if @error

        issuer.create(client, scopes, custom_token_attributes_with_data.merge(dpop_token_attributes))
      end

      private

      def validate_resource_indicators
        validator = Doorkeeper.config.resource_indicator_validator
        return true unless validator
        return true if @raw_resource_indicators.blank?

        @resolved_resource_indicators = ResourceIndicatorValidator.validate!(
          @raw_resource_indicators,
          config_validator: validator,
          client: client,
        )
        true
      rescue Errors::InvalidTarget
        false
      end

      def custom_token_attributes_with_data
        attrs = parameters
          .with_indifferent_access
          .slice(*Doorkeeper.config.custom_access_token_attributes)
          .symbolize_keys

        # RFC 8707: attach validated resource indicators to token attributes
        if @resolved_resource_indicators.present?
          unless Doorkeeper.config.access_token_model.resource_indicators_supported?
            raise Errors::MissingResourceColumn, "oauth_access_tokens"
          end

          attrs[:resource] = @resolved_resource_indicators.join(" ")
        end

        attrs
      end
    end
  end
end
