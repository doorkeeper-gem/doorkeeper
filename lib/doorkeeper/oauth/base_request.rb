module Doorkeeper
  module OAuth
    class BaseRequest
      include Validations

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
        @scopes ||= if @original_scopes.present?
                      OAuth::Scopes.from_string(@original_scopes)
                    else
                      default_scopes
                    end
      end

      def default_scopes
        server.default_scopes
      end

      def valid?
        error.nil?
      end

      def find_or_create_access_token(client, resource_owner_id, scopes, server)
        r_owner_accessor = Doorkeeper.configuration.resource_owner_accessor.constantize
        resource_owner = r_owner_accessor.get_by_id(resource_owner_id)
        @access_token = AccessToken.find_or_create_for(
          client,
          resource_owner,
          scopes,
          Authorization::Token.access_token_expires_in(server, client),
          server.refresh_token_enabled?
        )
      end

      def before_successful_response
      end

      def after_successful_response
      end
    end
  end
end
