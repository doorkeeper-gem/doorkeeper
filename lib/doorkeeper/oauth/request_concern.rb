module Doorkeeper
  module OAuth
    module RequestConcern
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
                      requested_scopes
                    else
                      default_scopes
                    end
      end

      def requested_scopes
        if default_scopes_persistent?
          default_scopes + optional_scopes
        else
          optional_scopes
        end
      end

      def optional_scopes
        Doorkeeper::OAuth::Scopes.from_string(@original_scopes)
      end

      def default_scopes_persistent?
        Doorkeeper.configuration.default_scopes_persistent?
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

      def before_successful_response
      end

      def after_successful_response
      end
    end
  end
end
