module Doorkeeper
  module Request
    class Token
      attr_accessor :pre_auth, :server

      def initialize(server)
        @pre_auth = server.context.send(:pre_auth)
        @server = server
      end

      def request
        @request ||= OAuth::TokenRequest.new(pre_auth, server.current_resource_owner)
      end

      def authorize
        request.authorize
      end
    end
  end
end
