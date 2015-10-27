require 'doorkeeper/request/strategy'

module Doorkeeper
  module Request
    class AuthorizationCode < Strategy
      attr_accessor :grant, :client

      def initialize(server)
        super
        @grant, @client = server.grant, server.client
      end

      def request
        @request ||= OAuth::AuthorizationCodeRequest.new(Doorkeeper.configuration, grant, client, server.parameters)
      end
    end
  end
end
