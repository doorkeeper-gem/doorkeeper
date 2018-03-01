module Doorkeeper
  module OAuth
    class VhostlessAccessTokenRequest < BaseRequest
      include OAuth::Helpers

      validate :client,         error: :invalid_client
      validate :resource_owner, error: :invalid_grant
      validate :scopes,         error: :invalid_scope

      attr_accessor :server, :client, :resource_owners, :parameters,
                    :access_tokens

      def initialize(server, client, resource_owners, parameters = {})
        @server          = server
        @resource_owners = resource_owners
        @client          = client
        @parameters      = parameters
        @original_scopes = parameters[:scope]
      end

      def authorize
        validate
        if valid?
          before_successful_response
          @response = MultiTokenResponse.new(access_tokens)
          after_successful_response
          @response
        else
          @response = ErrorResponse.from_request(self)
        end
      end

      private

      def before_successful_response
        find_or_create_access_tokens(client, resource_owners, scopes, server)
      end

      def find_or_create_access_tokens(client, resource_owners, scopes, server)
        @access_tokens = resource_owners.map do |resource_owner|
          AccessToken.find_or_create_for(
            client,
            resource_owner,
            scopes,
            Authorization::Token.access_token_expires_in(server, client),
            server.refresh_token_enabled?
          )
        end
      end

      def validate_scopes
        return true unless @original_scopes.present?
        ScopeChecker.valid? @original_scopes, server.scopes, client.try(:scopes)
      end

      def validate_resource_owner
        resource_owners.any?
      end

      def validate_client
        !parameters[:client_id] || !!client
      end
    end
  end
end
