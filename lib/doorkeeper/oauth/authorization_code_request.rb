module Doorkeeper
  module OAuth
    class AuthorizationCodeRequest < BaseRequest
      validate :attributes,   error: :invalid_request
      validate :client,       error: :invalid_client
      validate :grant,        error: :invalid_grant
      validate :redirect_uri, error: :invalid_grant
      validate :code_verifier,error: :invalid_grant

      attr_accessor :server, :grant, :client, :redirect_uri, :access_token, :code_verifier

      def initialize(server, grant, client, parameters = {})
        @server = server
        @client = client
        @grant  = grant
        @redirect_uri = parameters[:redirect_uri]
        @code_verifier = parameters[:code_verifier]
      end

      private

      def before_successful_response
        grant.transaction do
          grant.lock!
          raise Errors::InvalidGrantReuse if grant.revoked?

          grant.revoke
          find_or_create_access_token(grant.application,
                                      grant.resource_owner_id,
                                      grant.scopes,
                                      server)
        end
      end

      def validate_attributes
        if grant && grant.uses_pkce?
          return false if code_verifier.blank?
        end

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

      def validate_code_verifier
        return true unless grant.uses_pkce?
        if grant.code_challenge_method == 'S256'
          grant.code_challenge == Base64.urlsafe_encode64(Digest::SHA256.digest(code_verifier))
        elsif grant.code_challenge_method == 'plain'
          grant.code_challenge == code_verifier
        else
          false
        end
      end
    end
  end
end
