module Doorkeeper
  module Request
    class ClientCredentials
      attr_accessor :client, :server

      def initialize(server)
        @client, @server = server.client, server
      end

      def request
        @request ||= OAuth::ClientCredentialsRequest.new(Doorkeeper.configuration, client, server.parameters)
      end

      def authorize
        request.authorize
      end
    end
  end
end
