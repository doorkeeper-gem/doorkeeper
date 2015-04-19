module Doorkeeper
  module OAuth
    class RefreshTokenRequest
      include Validations
      include OAuth::RequestConcern
      include OAuth::Helpers

      validate :token_presence, error: :invalid_request
      validate :token,        error: :invalid_grant
      validate :client,       error: :invalid_client
      validate :client_match, error: :invalid_grant
      validate :scope,        error: :invalid_scope

      attr_accessor :access_token, :client, :credentials, :refresh_token,
                    :server

      def initialize(server, refresh_token, credentials, parameters = {})
        @server          = server
        @refresh_token   = refresh_token
        @credentials     = credentials
        @original_scopes = parameters[:scope] || parameters[:scopes]
        @refresh_token_parameter = parameters[:refresh_token]

        if credentials
          @client = Application.by_uid_and_secret credentials.uid,
                                                  credentials.secret
        end
      end

      private

      attr_reader :refresh_token_parameter

      def before_successful_response
        refresh_token.revoke
        create_access_token
      end

      def default_scopes
        refresh_token.scopes
      end

      def create_access_token
        expires_in = Authorization::Token.access_token_expires_in(
          server,
          client
        )

        @access_token = AccessToken.create!(
          application_id: refresh_token.application_id,
          resource_owner_id: refresh_token.resource_owner_id,
          scopes: scopes.to_s,
          expires_in: expires_in,
          use_refresh_token: true)
      end

      def validate_token_presence
        refresh_token.present? || refresh_token_parameter.present?
      end

      def validate_token
        refresh_token.present? && !refresh_token.revoked?
      end

      def validate_client
        !credentials || !!client
      end

      def validate_client_match
        !client || refresh_token.application_id == client.id
      end

      def validate_scope
        if @original_scopes.present?
          ScopeChecker.valid?(@original_scopes, refresh_token.scopes)
        else
          true
        end
      end
    end
  end
end
