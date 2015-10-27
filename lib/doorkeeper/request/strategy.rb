module Doorkeeper
  module Request
    class Strategy
      attr_accessor :server

      def initialize(server)
        self.server = server
      end

      def request
        raise NotImplementedError, "request strategies must define #request"
      end

      def authorize
        request.authorize
      end
    end
  end
end
