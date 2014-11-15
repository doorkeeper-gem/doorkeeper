module Doorkeeper
  module Request
    class AuthorizationCode
      def self.build(server)
        new(server.grant, client(server), server)
      end

      # If the credentials are present, use it to authenticate the client.
      # if not, use only the uid to fetch the client.
      def self.client(server)
        if server.credentials.present?
          server.client
        else
          server.client_via_uid
        end
      end

      attr_accessor :grant, :client, :server

      def initialize(grant, client, server)
        @grant, @client, @server = grant, client, server
      end

      def request
        @request ||= OAuth::AuthorizationCodeRequest.new(Doorkeeper.configuration, grant, client, server.parameters)
      end

      def authorize
        request.authorize
      end
    end
  end
end
