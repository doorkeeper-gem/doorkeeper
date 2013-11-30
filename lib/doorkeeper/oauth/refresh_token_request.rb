module Doorkeeper
  module OAuth
    class RefreshTokenRequest
      include Doorkeeper::Validations

      validate :token,        :error => :invalid_request
      validate :client,       :error => :invalid_client
      validate :client_match, :error => :invalid_grant

      attr_accessor :server, :refresh_token, :credentials, :access_token
      attr_accessor :client

      # TODO: refresh token can receive scope as parameters
      def initialize(server, refresh_token, credentials)
        @server        = server
        @refresh_token = refresh_token
        @credentials   = credentials

        @client = Doorkeeper::Application.authenticate(credentials.uid, credentials.secret) if credentials
      end

      def authorize
        validate
        @response = if valid?
          revoke_and_create_access_token
          TokenResponse.new access_token
        else
          ErrorResponse.from_request self
        end
      end

      def valid?
        self.error.nil?
      end

    private

      def revoke_and_create_access_token
        refresh_token.revoke
        create_access_token
      end

      def create_access_token
        @access_token = Doorkeeper::AccessToken.create!({
          :application_id    => refresh_token.application_id,
          :resource_owner_id => refresh_token.resource_owner_id,
          :scopes            => refresh_token.scopes_string,
          :expires_in        => server.access_token_expires_in,
          :use_refresh_token => true
        })
      end

      def validate_token
        refresh_token.present? && !refresh_token.revoked?
      end

      def validate_client
        (!credentials || !!client)
      end

      def validate_client_match
        !client || refresh_token.application_id == client.id
      end
    end
  end
end
