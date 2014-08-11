module Doorkeeper
  module Helpers
    module Controller
      extend ActiveSupport::Concern

      private

      def authenticate_resource_owner!
        current_resource_owner
      end

      def current_resource_owner
        instance_eval(&Doorkeeper.configuration.authenticate_resource_owner)
      end

      def resource_owner_from_credentials
        instance_eval(&Doorkeeper.configuration.resource_owner_from_credentials)
      end

      def authenticate_admin!
        instance_eval(&Doorkeeper.configuration.authenticate_admin)
      end

      def server
        @server ||= Server.new(self)
      end

      def doorkeeper_token
        @token ||= OAuth::Token.authenticate request, *config_methods
      end

      def config_methods
        @methods ||= Doorkeeper.configuration.access_token_methods
      end

      def get_error_response_from_exception(exception)
        error_name = case exception
                     when Errors::InvalidTokenStrategy
                       :unsupported_grant_type
                     when Errors::InvalidAuthorizationStrategy
                       :unsupported_response_type
                     when Errors::MissingRequestStrategy
                       :invalid_request
                     end

        OAuth::ErrorResponse.new name: error_name, state: params[:state]
      end

      def handle_token_exception(exception)
        error = get_error_response_from_exception exception
        self.headers.merge! error.headers
        self.response_body = error.body.to_json
        self.status        = error.status
      end

      def skip_authorization?
        !!instance_exec([@server.current_resource_owner, @pre_auth.client], &Doorkeeper.configuration.skip_authorization)
      end
    end
  end
end
