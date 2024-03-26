# frozen_string_literal: true

module Doorkeeper
  module OAuth
    class AuthorizationCodeRequest < BaseRequest
      validate :params,       error: Errors::InvalidRequest
      validate :client,       error: Errors::InvalidClient
      validate :grant,        error: Errors::InvalidGrant
      # @see https://datatracker.ietf.org/doc/html/rfc6749#section-5.2
      validate :redirect_uri, error: Errors::InvalidGrant
      validate :code_verifier, error: Errors::InvalidGrant

      attr_reader :grant, :client, :redirect_uri, :access_token, :code_verifier,
                  :invalid_request_reason, :missing_param

      def initialize(server, grant, client, parameters = {})
        @server = server
        @client = client
        @grant  = grant
        @grant_type = Doorkeeper::OAuth::AUTHORIZATION_CODE
        @redirect_uri = parameters[:redirect_uri]
        @code_verifier = parameters[:code_verifier]
      end

      private

      def before_successful_response
        grant.transaction do
          grant.lock!
          raise Errors::InvalidGrantReuse if grant.revoked?

          grant.revoke

          find_or_create_access_token(
            client,
            resource_owner,
            grant.scopes,
            custom_token_attributes_with_data,
            server,
          )
        end

        super
      end

      def resource_owner
        if Doorkeeper.config.polymorphic_resource_owner?
          grant.resource_owner
        else
          grant.resource_owner_id
        end
      end

      def pkce_supported?
        Doorkeeper.config.access_grant_model.pkce_supported?
      end

      def validate_params
        @missing_param =
          if grant&.uses_pkce? && code_verifier.blank?
            :code_verifier
          elsif redirect_uri.blank? && !allow_blank_redirect_uri?
            :redirect_uri
          end

        @missing_param.nil?
      end

      def validate_client
        client.present?
      end

      def validate_grant
        return false unless grant && grant.application_id == client.id

        grant.accessible?
      end

      def validate_redirect_uri
        # 4.1.3.  Access Token Request
        #   redirect_uri
        #       REQUIRED, if the "redirect_uri" parameter was included in the
        #       authorization request as described in Section 4.1.1, and their
        #       values MUST be identical.
        #
        return true if redirect_uri.nil? && allow_blank_redirect_uri?

        Helpers::URIChecker.valid_for_authorization?(
          redirect_uri,
          grant.redirect_uri,
        )
      end

      # if either side (server or client) request PKCE, check the verifier
      # against the DB - if PKCE is supported
      def validate_code_verifier
        return true unless pkce_supported?
        return grant.code_challenge.blank? if code_verifier.blank?

        if grant.code_challenge_method == "S256"
          grant.code_challenge == generate_code_challenge(code_verifier)
        elsif grant.code_challenge_method == "plain"
          grant.code_challenge == code_verifier
        else
          false
        end
      end

      def generate_code_challenge(code_verifier)
        Doorkeeper.config.access_grant_model.generate_code_challenge(code_verifier)
      end

      def custom_token_attributes_with_data
        grant
          .attributes
          .with_indifferent_access
          .slice(*Doorkeeper.config.custom_access_token_attributes)
          .symbolize_keys
      end

      def allow_blank_redirect_uri?
        return @client_requires_redirect_uri if defined?(@client_requires_redirect_uri)

        @client_requires_redirect_uri = grant&.redirect_uri.blank?
      end
    end
  end
end
