module Doorkeeper
  module OAuth
    module RequestConcern
      def authorize
        validate
        if valid?
          on_successful_authorization
          @response = TokenResponse.new(access_token)
        else
          @response = ErrorResponse.from_request(self)
        end
      end

      def scopes
        @scopes ||= if @original_scopes.present?
                      Doorkeeper::OAuth::Scopes.from_string(@original_scopes)
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
        @access_token = Doorkeeper::AccessToken.find_or_create_for(
          client,
          resource_owner_id,
          scopes,
          server.access_token_expires_in,
          server.refresh_token_enabled?)
      end

      def on_successful_authorization
      end
    end
  end
end
