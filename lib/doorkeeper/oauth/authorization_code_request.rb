module Doorkeeper
  module OAuth
    class AuthorizationCodeRequest
      include Doorkeeper::Validations

      validate :attributes,   :error => :invalid_request
      validate :client,       :error => :invalid_client
      validate :grant,        :error => :invalid_grant
      validate :redirect_uri, :error => :invalid_grant

      attr_accessor :server, :grant, :client, :redirect_uri

      def initialize(server, grant, client, parameters = {})
        @server = server
        @client = client
        @grant  = grant
        @redirect_uri = parameters[:redirect_uri]

        unless Doorkeeper.configuration.require_redirect_uri
          @redirect_uri ||= grant && grant.redirect_uri
        end
      end

      def authorize
        validate
        @response = if valid?
          grant.revoke
          find_or_create_access_token
          TokenResponse.new access_token
        else
          ErrorResponse.from_request self
        end
      end

      def valid?
        self.error.nil?
      end

      def access_token
        @access_token ||= Doorkeeper::AccessToken.matching_token_for client, grant.resource_owner_id, grant.scopes
      end

      private

      def find_or_create_access_token
        if access_token
          access_token.expired? ? revoke_and_create_access_token : access_token
        else
          create_access_token
        end
      end

      def revoke_and_create_access_token
        access_token.revoke
        create_access_token
      end

      def create_access_token
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
        if grant.redirect_uri.present?
          grant.redirect_uri == redirect_uri
        else
          !Doorkeeper.configuration.require_redirect_uri
        end
      end
    end
  end
end
