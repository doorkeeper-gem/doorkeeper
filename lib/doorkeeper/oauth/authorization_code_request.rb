module Doorkeeper
  module OAuth
    class AuthorizationCodeRequest
      include Doorkeeper::Validations

      validate :attributes,   :error => :invalid_request
      validate :client,       :error => :invalid_client
      validate :grant,        :error => :invalid_grant
      validate :redirect_uri, :error => :invalid_grant

      attr_accessor :server, :grant, :client, :redirect_uri, :access_token

      def initialize(server, grant, client, parameters = {})
        @server = server
        @client = client
        @grant  = grant
        @redirect_uri = parameters[:redirect_uri]
      end

      def authorize
        validate
        @response = if valid?
          grant.revoke
          issue_token
          TokenResponse.new access_token
        else
          ErrorResponse.from_request self
        end
      end

      def valid?
        self.error.nil?
      end

    private

      def issue_token
        @access_token = Doorkeeper::AccessToken.create!({
          :application_id    => grant.application_id,
          :resource_owner_id => grant.resource_owner_id,
          :scopes            => grant.scopes_string,
          :expires_in        => server.access_token_expires_in,
          :use_refresh_token => server.refresh_token_enabled?
        })
      end

      def validate_attributes
        redirect_uri.present?
      end

      def validate_client
        !!client
      end

      def validate_grant
        return false unless grant && grant.application_id == client.id
        grant.accessible?
      end

      def validate_redirect_uri
        grant.redirect_uri == redirect_uri
      end
    end
  end
end
