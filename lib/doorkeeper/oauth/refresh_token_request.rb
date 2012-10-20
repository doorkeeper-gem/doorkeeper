module Doorkeeper
  module OAuth
    class RefreshTokenRequest
      include Doorkeeper::Validations

      validate :token,  :error => :invalid_request
      validate :client, :error => :invalid_client

      attr_accessor :server, :refresh_token, :client, :access_token

      # TODO: refresh token can receive scope as parameters
      def initialize(server, refresh_token, client)
        @server        = server
        @refresh_token = refresh_token
        @client        = client
        validate
      end

      def authorize
        revoke_and_create_access_token if valid?
      end

      def authorization
        {
          'access_token'  => access_token.token,
          'token_type'    => access_token.token_type,
          'expires_in'    => access_token.expires_in,
          'refresh_token' => access_token.refresh_token,
        }
      end

      def valid?
        self.error.nil?
      end

      def token_type
        "bearer"
      end

      def error_response
        Doorkeeper::OAuth::ErrorResponse.from_request(self)
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
        client.present? && refresh_token.application_id == client.id
      end
    end
  end
end
