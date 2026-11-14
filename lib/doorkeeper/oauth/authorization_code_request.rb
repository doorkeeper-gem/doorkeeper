# frozen_string_literal: true

module Doorkeeper
  module OAuth
    class AuthorizationCodeRequest < BaseRequest
      validate :params,       error: Errors::InvalidRequest
      validate :client,       error: Errors::InvalidClient
      validate :grant,        error: Errors::InvalidGrant
      # @see https://datatracker.ietf.org/doc/html/rfc6749#section-5.2
      validate :redirect_uri, error: Errors::InvalidGrant
      # Runs before :code_verifier, which has nothing to verify against when
      # the PKCE columns are missing.
      validate :pkce_storage, error: Errors::ServerError
      validate :code_verifier, error: Errors::InvalidGrant

      attr_reader :grant, :client, :redirect_uri, :access_token, :code_verifier,
                  :invalid_request_reason, :missing_param

      def initialize(server, grant, client, parameters = {})
        super()
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

          if Doorkeeper.config.revoke_previous_authorization_code_token?
            revoke_previous_tokens(grant.application, resource_owner)
          end

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
          elsif client && !client.confidential && Doorkeeper.config.force_pkce? && code_verifier.blank?
            :code_verifier
          elsif redirect_uri.blank?
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
        Helpers::URIChecker.valid_for_authorization?(
          redirect_uri,
          grant.redirect_uri,
        )
      end

      # With force_pkce the code_verifier of a non-confidential client must be
      # checked against the challenge stored on the grant. Without the columns
      # the doorkeeper:pkce generator adds there is no stored challenge, and
      # #validate_code_verifier would accept any verifier. Refuse the exchange
      # with server_error instead (see PreAuthorization#validate_pkce_storage,
      # which stops such a code from being issued in the first place).
      def validate_pkce_storage
        return true unless Doorkeeper.config.force_pkce?
        return true if client.confidential
        return true if pkce_supported?

        ::Rails.logger.error(
          "[DOORKEEPER] force_pkce is enabled but the PKCE columns are missing from the " \
          "oauth_access_grants table, so authorization codes cannot be exchanged. " \
          "Run `rails generate doorkeeper:pkce` and apply the migration.",
        )
        false
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

      def revoke_previous_tokens(application, resource_owner)
        Doorkeeper.config.access_token_model.revoke_all_for(application.id, resource_owner)
      end
    end
  end
end
