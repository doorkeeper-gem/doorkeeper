module Doorkeeper
  module OAuth
    class PasswordAccessTokenRequest
      include Validations
      include OAuth::RequestConcern
      include OAuth::Helpers

      validate :client,         error: :invalid_client
      validate :resource_owner, error: :invalid_grant
      validate :scopes,         error: :invalid_scope

      attr_accessor :server, :resource_owner, :credentials, :access_token
      attr_accessor :client

      def initialize(server, credentials, resource_owner, parameters = {})
        @server          = server
        @resource_owner  = resource_owner
        @credentials     = credentials
        @original_scopes = parameters[:scope]

        if credentials
          @client = Application.by_uid_and_secret credentials.uid,
                                                  credentials.secret
        end
      end

      private

      def before_successful_response
        find_or_create_access_token(client, resource_owner.id, scopes, server)
      end

      def validate_scopes
        return true unless @original_scopes.present?
        ScopeChecker.valid? @original_scopes, server.scopes, client.try(:scopes)
      end

      def validate_resource_owner
        !!resource_owner
      end

      def validate_client
        !credentials || !!client
      end
    end
  end
end
