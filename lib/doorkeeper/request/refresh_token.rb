module Doorkeeper
  module Request
    class RefreshToken
      def self.build(server)
        new(server.current_refresh_token, server.client)
      end

      attr_accessor :refresh_token, :client

      def initialize(refresh_token, client)
        @refresh_token, @client = refresh_token, client
      end

      def request
        @request ||= OAuth::RefreshTokenRequest.new(Doorkeeper.configuration, refresh_token, client)
      end

      def authorize
        request.authorize
      end
    end
  end
end
