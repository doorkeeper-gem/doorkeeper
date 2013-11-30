module Doorkeeper
  module Request
    class RefreshToken
      def self.build(server)
        new(server.current_refresh_token, server.credentials)
      end

      attr_accessor :refresh_token, :credentials

      def initialize(refresh_token, credentials)
        @refresh_token, @credentials = refresh_token, credentials
      end

      def request
        @request ||= OAuth::RefreshTokenRequest.new(Doorkeeper.configuration, refresh_token, credentials)
      end

      def authorize
        request.authorize
      end
    end
  end
end
