# frozen_string_literal: true

module Doorkeeper
  module OAuth
    class PasswordAccessTokenRequest < BaseRequest
      include OAuth::Helpers

      validate :client, error: :invalid_client
      validate :client_supports_grant_flow, error: :unauthorized_client
      validate :resource_owner, error: :invalid_grant
      validate :scopes, error: :invalid_scope

      attr_reader :client, :credentials, :resource_owner, :parameters, :access_token

      def initialize(server, client, credentials, resource_owner, parameters = {})
        @server          = server
        @resource_owner  = resource_owner
        @client          = client
        @credentials     = credentials
        @parameters      = parameters
        @original_scopes = parameters[:scope]
        @grant_type      = Doorkeeper::OAuth::PASSWORD
      end

      private

      def before_successful_response
        find_or_create_access_token(client, resource_owner, scopes, server)
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
        server_config.allow_grant_flow_for_client?(grant_type, client&.application)
      end
    end
  end
end
