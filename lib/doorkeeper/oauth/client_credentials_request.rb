# frozen_string_literal: true

module Doorkeeper
  module OAuth
    class ClientCredentialsRequest < BaseRequest
      attr_reader :client, :original_scopes, :parameters, :response

      alias error_response response

      delegate :error, to: :issuer

      def initialize(server, client, parameters = {})
        @client = client
        @server = server
        @response = nil
        @original_scopes = parameters[:scope]
        @parameters = parameters.except(:scope)
      end

      def access_token
        issuer.token
      end

      def issuer
        @issuer ||= ClientCredentials::Issuer.new(
          server,
          ClientCredentials::Validator.new(server, self),
        )
      end

      private

      def valid?
        issuer.create(client, scopes, custom_token_attributes_with_data)
      end

      def custom_token_attributes_with_data
        parameters
          .with_indifferent_access
          .slice(*Doorkeeper.config.custom_access_token_attributes)
          .symbolize_keys
      end
    end
  end
end
