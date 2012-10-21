module Doorkeeper
  module OAuth
    class TokenResponse
      attr_accessor :token

      def initialize(token)
        @token = token
      end

      def body
        {
          'access_token'  => token.token,
          'token_type'    => token.token_type,
          'expires_in'    => token.expires_in,
          'refresh_token' => token.refresh_token,
          'scope'         => token.scopes_string
        }
      end

      def status
        :success
      end

      def headers
        { 'Cache-Control' => 'no-store', 'Pragma' => 'no-cache' }
      end
    end
  end
end
