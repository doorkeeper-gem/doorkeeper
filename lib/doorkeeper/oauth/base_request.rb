# frozen_string_literal: true

module Doorkeeper
  module OAuth
    class BaseRequest
      include Validations

      attr_reader :grant_type, :server

      delegate :default_scopes, to: :server

      def authorize
        if valid?
          before_successful_response
          @response = TokenResponse.new(access_token)
          after_successful_response
          @response
        elsif error == :invalid_request
          @response = InvalidRequestResponse.from_request(self)
        else
          @response = ErrorResponse.from_request(self)
        end
      end

      def scopes
        @scopes ||= build_scopes
      end

      def find_or_create_access_token(client, resource_owner, scopes, additional_fields, server)
        context = Authorization::Token.build_context(client, grant_type, scopes, resource_owner)
        token_model = server_config.access_token_model

        token_params = {
          application: client,
          resource_owner: resource_owner,
          scopes: scopes,
          expires_in: Authorization::Token.access_token_expires_in(server, context),
          use_refresh_token: Authorization::Token.refresh_token_enabled?(server, context)
        }
        additional_fields.select! { |k, _v| token_model.respond_to?(k) }

        @access_token = token_model.find_or_create_for(token_params.merge(additional_fields))
      end

      def before_successful_response
        server_config.before_successful_strategy_response.call(self)
      end

      def after_successful_response
        server_config.after_successful_strategy_response.call(self, @response)
      end

      def server_config
        Doorkeeper.config
      end

      private

      def build_scopes
        if @original_scopes.present?
          OAuth::Scopes.from_string(@original_scopes)
        else
          client_scopes = @client&.scopes
          return default_scopes if client_scopes.blank?

          default_scopes & client_scopes
        end
      end
    end
  end
end
