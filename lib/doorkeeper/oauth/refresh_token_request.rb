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

      attr_accessor :server, :refresh_token, :credentials, :access_token
      attr_accessor :client

      def initialize(server, refresh_token, credentials, parameters = {})
        @server          = server
        @refresh_token   = refresh_token
        @credentials     = credentials
        @original_scopes = parameters[:scopes]
        @refresh_token_parameter = parameters[:refresh_token]

        if credentials
          @client = Application.by_uid_and_secret credentials.uid,
                                                  credentials.secret
        end
      end

      private

      attr_reader :refresh_token_parameter

      def before_successful_response
        refresh_token.revoke_in(server.refresh_token_revoked_in) unless refresh_token.revoked_at || server.refresh_token_revoked_on_use
        create_access_token
      end

      def default_scopes
        refresh_token.scopes
      end

      def create_access_token
        create_params = {
          application_id:    refresh_token.application_id,
          resource_owner_id: refresh_token.resource_owner_id,
          scopes:            scopes.to_s,
          expires_in:        server.access_token_expires_in,
          use_refresh_token: true
        }
        create_params[:previous_refresh_token] = refresh_token.refresh_token if server.refresh_token_revoked_on_use
        @access_token = AccessToken.create! create_params
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
