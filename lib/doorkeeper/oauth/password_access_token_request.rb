# frozen_string_literal: true

module Doorkeeper
  module OAuth
    class PasswordAccessTokenRequest < BaseRequest
      include OAuth::Helpers

      validate :client, error: Errors::InvalidClient
      validate :client_supports_grant_flow, error: Errors::UnauthorizedClient
      validate :resource_owner, error: Errors::InvalidGrant
      validate :scopes, error: Errors::InvalidScope
      validate :resource_indicators, error: Errors::InvalidTarget

      attr_reader :client, :credentials, :resource_owner, :parameters, :access_token

      def initialize(server, client, credentials, resource_owner, parameters = {}, dpop_proof: nil)
        super(dpop_proof: dpop_proof)
        @server          = server
        @resource_owner  = resource_owner
        @client          = client
        @credentials     = credentials
        @parameters      = parameters
        @original_scopes = parameters[:scope]
        @grant_type      = Doorkeeper::OAuth::PASSWORD
        @raw_resource_indicators = parameters[:resource]
      end

      private

      def before_successful_response
        token_attributes = {}
        if @resolved_resource_indicators.present?
          unless Doorkeeper.config.access_token_model.resource_indicators_supported?
            raise Errors::MissingResourceColumn, "oauth_access_tokens"
          end

          token_attributes[:resource] = @resolved_resource_indicators.join(" ")
        end
        find_or_create_access_token(client, resource_owner, scopes, token_attributes, server)
        super
      end

      def validate_scopes
        return true if scopes.blank?

        ScopeChecker.valid?(
          scope_str: scopes.to_s,
          server_scopes: server.scopes,
          app_scopes: client.try(:scopes),
          grant_type: grant_type,
        )
      end

      def validate_resource_owner
        resource_owner.present?
      end

      # Section 4.3.2. Access Token Request for Resource Owner Password Credentials Grant:
      #
      #   If the client type is confidential or the client was issued client credentials (or assigned
      #   other authentication requirements), the client MUST authenticate with the authorization
      #   server as described in Section 3.2.1.
      #
      #   The authorization server MUST:
      #
      #    o  require client authentication for confidential clients or for any  client that was
      #       issued client credentials (or with other authentication requirements)
      #
      #    o  authenticate the client if client authentication is included,
      #
      #   @see https://datatracker.ietf.org/doc/html/rfc6749#section-4.3
      #
      def validate_client
        if Doorkeeper.config.skip_client_authentication_for_password_grant
          client.present? || (!parameters[:client_id] && credentials.blank?)
        else
          client.present?
        end
      end

      def validate_client_supports_grant_flow
        Doorkeeper.config.allow_grant_flow_for_client?(grant_type, client&.application)
      end

      # RFC 8707: validate resource indicators against server policy.
      def validate_resource_indicators
        validator = Doorkeeper.config.resource_indicator_validator
        return true unless validator

        @resolved_resource_indicators = ResourceIndicatorValidator.validate!(
          @raw_resource_indicators,
          config_validator: validator,
          client: client,
        )
        true
      rescue Errors::InvalidTarget
        false
      end
    end
  end
end
