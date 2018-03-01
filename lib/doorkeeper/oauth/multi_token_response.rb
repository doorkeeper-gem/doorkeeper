module Doorkeeper
  module OAuth
    class MultiTokenResponse
      attr_accessor :tokens

      def initialize(tokens)
        @tokens = tokens
      end

      def body
        tokens.map do |token|
          {
            'access_token'  => token.token,
            'token_type'    => token.token_type,
            'expires_in'    => token.expires_in_seconds,
            'refresh_token' => token.refresh_token,
            'scope'         => token.scopes_string,
            'created_at'    => token.created_at.to_i
          }.reject { |_, value| value.blank? }
        end
      end

      def status
        :ok
      end

      def headers
        { 'Cache-Control' => 'no-store',
          'Pragma' => 'no-cache',
          'Content-Type' => 'application/json; charset=utf-8' }
      end
    end
  end
end
