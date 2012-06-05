require 'doorkeeper/oauth/error'
require 'doorkeeper/oauth/error_response'
require 'doorkeeper/oauth/scopes'
require 'doorkeeper/oauth/client_credentials/creator'
require 'doorkeeper/oauth/client_credentials/issuer'
require 'doorkeeper/oauth/client_credentials/response'
require 'doorkeeper/oauth/client_credentials/validation'

module Doorkeeper
  module OAuth
    class ClientCredentialsRequest
      attr_accessor :issuer, :server, :client, :original_scopes, :scopes
      attr_reader   :response
      alias         :authorization :response  # Remove this when API is consistent
      alias         :error_response :response

      delegate :error, :to => :issuer

      def issuer
        @issuer ||= Issuer.new(server, Validation.new(server, self))
      end

      def initialize(server, client, parameters = {})
        @client, @server = client, server
        @response        = nil
        @original_scopes = parameters[:scope]
      end

      def authorize
        @response = if issuer.create(client, scopes)
          Response.new(issuer.token)
        else
          ErrorResponse.from_request(self)
        end
      end

      def scopes
        @scopes ||= if @original_scopes.present?
          Doorkeeper::OAuth::Scopes.from_string(@original_scopes)
        else
          server.default_scopes
        end
      end
    end
  end
end
