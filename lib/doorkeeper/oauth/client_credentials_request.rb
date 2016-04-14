require 'doorkeeper/oauth/client_credentials/creator'
require 'doorkeeper/oauth/client_credentials/issuer'
require 'doorkeeper/oauth/client_credentials/validation'

module Doorkeeper
  module OAuth
    class ClientCredentialsRequest
      include Validations
      include OAuth::RequestConcern

      attr_accessor :server, :client, :original_scopes
      attr_reader :response
      attr_writer :issuer

      alias :error_response :response

      delegate :error, to: :issuer

      def issuer
        @issuer ||= Issuer.new(server, Validation.new(server, self))
      end

      def initialize(server, client, parameters = {})
        @client, @server = client, server
        @response        = nil
        @original_scopes = parameters[:scope]
      end

      def access_token
        issuer.token
      end

      private

      def valid?
        issuer.create(client, scopes)
      end
    end
  end
end
