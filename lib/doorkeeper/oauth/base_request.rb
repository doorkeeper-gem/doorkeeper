module Doorkeeper
  module OAuth
    class BaseRequest
      include Validations

      attr_reader :grant_type

      def authorize
        validate

        if valid?
          before_successful_response
          @response = TokenResponse.new(access_token)
          after_successful_response
          @response
        else
          @response = ErrorResponse.from_request(self)
        end
      end

      def scopes
        @scopes ||= build_scopes
      end

      def default_scopes
        server.default_scopes
      end

      def valid?
        error.nil?
      end

      def find_or_create_access_token(client, resource_owner_id, scopes, server)
        context = Authorization::Token.build_context(client, grant_type, scopes)
        @access_token = AccessToken.find_or_create_for(
          client,
          resource_owner_id,
          scopes,
          Authorization::Token.access_token_expires_in(server, context),
          Authorization::Token.refresh_token_enabled?(server, context)
        )
      end

      def before_successful_response
        Doorkeeper.configuration.before_successful_strategy_response.call(self)
      end

      def after_successful_response
        Doorkeeper.configuration.after_successful_strategy_response.call(self, @response)
      end

      private

      def build_scopes
        if @original_scopes.present?
          OAuth::Scopes.from_string(@original_scopes)
        else
          client_scopes = @client.try(:scopes)
          return default_scopes if client_scopes.blank?

          default_scopes & @client.scopes
        end
      end
    end
  end
end
