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
      # Runs last, so the single-use enforcement it performs only acts once
      # the caller has proven possession of the code (redirect_uri + PKCE).
      validate :grant_accessible, error: Errors::InvalidGrant

      attr_reader :grant, :client, :redirect_uri, :access_token, :code_verifier,
                  :invalid_request_reason, :missing_param

      # A scope parameter is deliberately not read here: RFC 6749 does not
      # define one for the authorization_code token request (§4.1.3), so it
      # is ignored and the access token inherits the scopes of the grant.
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

          link_access_token_to_grant
        end

        super
      rescue Errors::InvalidGrantReuse
        # A concurrent exchange of the same code won the race: the raise
        # rolled this transaction back, so the revocation must happen
        # outside of it. `lock!` reloaded the grant after the winning
        # exchange committed, so the token linkage is visible here.
        revoke_token_issued_for_grant
        raise
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
          elsif client && Doorkeeper.config.force_pkce? && code_verifier.blank?
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
        grant && grant.application_id == client.id
      end

      # Checked after redirect_uri and PKCE so that a caller who cannot prove
      # possession of the code never reaches the reuse handling below.
      def validate_grant_accessible
        # Authorization codes are single-use (RFC 6749 §4.1.2): observing a
        # second exchange attempt denies the request and revokes the tokens
        # already issued for the code (§10.5).
        revoke_token_issued_for_grant if grant.revoked?

        grant.accessible?
      end

      def validate_redirect_uri
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

      def revoke_previous_tokens(application, resource_owner)
        Doorkeeper.config.access_token_model.revoke_all_for(application.id, resource_owner)
      end

      def link_access_token_to_grant
        return unless grant.class.access_token_revoked_on_reuse?

        grant.class.with_primary_role do
          grant.update_column(:access_token_id, access_token.id)
        end
      end

      def revoke_token_issued_for_grant
        return unless grant.class.access_token_revoked_on_reuse?
        return if grant.access_token_id.blank?

        # Look the token up on the primary too: a lagging read replica may not
        # have it yet, which would silently skip the revocation.
        Doorkeeper.config.access_token_model.with_primary_role do
          token = Doorkeeper.config.access_token_model.find_by(id: grant.access_token_id)
          token&.revoke
        end
      end
    end
  end
end
