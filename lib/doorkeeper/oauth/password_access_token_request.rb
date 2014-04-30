module Doorkeeper
  module OAuth
    class PasswordAccessTokenRequest
      include Doorkeeper::Validations
      include Doorkeeper::OAuth::Helpers

      validate :client,         error: :invalid_client
      validate :resource_owner, error: :invalid_resource_owner
      validate :scopes,         error: :invalid_scope

      attr_accessor :server, :resource_owner, :credentials, :access_token
      attr_accessor :client

      def initialize(server, credentials, resource_owner, parameters = {})
        @server          = server
        @resource_owner  = resource_owner
        @credentials     = credentials
        @original_scopes = parameters[:scope]

        if credentials
          @client = Doorkeeper::Application.authenticate credentials.uid,
                                                         credentials.secret
        end
      end

      def authorize
        validate
        @response = if valid?
                      issue_token
                      TokenResponse.new access_token
                    else
                      ErrorResponse.from_request self
                    end
      end

      def valid?
        error.nil?
      end

      def scopes
        @scopes ||= if @original_scopes.present?
                      Doorkeeper::OAuth::Scopes.from_string(@original_scopes)
                    else
                      server.default_scopes
                    end
      end

      private

      def issue_token
        @access_token = Doorkeeper::AccessToken.create!(
          application_id:    client.try(:id),
          resource_owner_id: resource_owner.id,
          scopes:            scopes.to_s,
          expires_in:        server.access_token_expires_in,
          use_refresh_token: server.refresh_token_enabled?
        )
      end

      def validate_scopes
        return true unless @original_scopes.present?
        ScopeChecker.valid?(@original_scopes, @server.scopes)
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
