require 'doorkeeper/request/strategy'

module Doorkeeper
  module Request
    class ClientCredentials < Strategy
      attr_accessor :client

      def initialize(server)
        super
        @client = server.client
      end

      def request
        @request ||= OAuth::ClientCredentialsRequest.new(Doorkeeper.configuration, client, server.parameters)
      end
    end
  end
end
