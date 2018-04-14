module Doorkeeper
  module OAuth
    class PasswordAccessTokenRequest < BaseRequest
      include OAuth::Helpers

      validate :client,         error: :invalid_client
      validate :resource_owner, error: :invalid_grant
      validate :scopes,         error: :invalid_scope

      attr_accessor :server, :client, :resource_owner, :parameters,
                    :access_token

      def initialize(server, client, resource_owner, parameters = {})
        @server          = server
        @resource_owner  = resource_owner
        @client          = client
        @parameters      = parameters
        @original_scopes = parameters[:scope]
        @grant_type      = Doorkeeper::OAuth::PASSWORD
      end

      private

      def before_successful_response
        find_or_create_access_token(client, resource_owner.id, scopes, server)
        super
      end

      def validate_scopes
        application_scopes = client.try(:scopes)
        return true if @original_scopes.blank? && application_scopes.blank?

        ScopeChecker.valid? @original_scopes, server.scopes, application_scopes
      end

      def validate_resource_owner
        !resource_owner.nil?
      end

      def validate_client
        !parameters[:client_id] || !client.nil?
      end
    end
  end
end
