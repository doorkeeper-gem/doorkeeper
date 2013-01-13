require 'doorkeeper/oauth/error'
require 'doorkeeper/oauth/error_response'
require 'doorkeeper/oauth/scopes'
require 'doorkeeper/oauth/token_response'
require 'doorkeeper/oauth/client_credentials/validation'

module Doorkeeper
  module OAuth
    class ClientCredentialsRequest
      def self.build(server)
        new(Doorkeeper.configuration, server.client, server.parameters)
      end

      attr_accessor :server, :client, :original_scopes, :scopes, :access_token
      attr_reader   :response
      alias         :error_response :response

      def initialize(server, client, parameters = {})
        @client, @server = client, server
        @response        = nil
        @original_scopes = parameters[:scope]
      end

      def authorize
        validation.validate
        @response = if validation.valid?
          issue_token
          TokenResponse.new access_token
        else
          ErrorResponse.from_request self
        end
      end

      # TODO: duplicated code in all flows
      def scopes
        @scopes ||= if @original_scopes.present?
          Doorkeeper::OAuth::Scopes.from_string(@original_scopes)
        else
          server.default_scopes
        end
      end

      def issue_token
        @access_token ||= Doorkeeper::AccessToken.create({
          :application_id    => client.id,
          :scopes            => scopes.to_s,
          :use_refresh_token => false,
          :expires_in        => server.access_token_expires_in
        })
      end

      delegate :error, :to => :validation
      def validation
        @validation ||= Validation.new(server, self)
      end
    end
  end
end
