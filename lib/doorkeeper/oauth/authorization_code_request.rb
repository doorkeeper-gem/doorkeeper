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
      validate :resource_indicators, error: Errors::InvalidTarget

      attr_reader :grant, :client, :redirect_uri, :access_token, :code_verifier,
                  :invalid_request_reason, :missing_param

      # A scope parameter is deliberately not read here: RFC 6749 does not
      # define one for the authorization_code token request (§4.1.3), so it
      # is ignored and the access token inherits the scopes of the grant.
      def initialize(server, grant, client, parameters = {}, dpop_proof: nil)
        super(dpop_proof: dpop_proof)
        @server = server
        @client = client
        @grant  = grant
        @grant_type = Doorkeeper::OAuth::AUTHORIZATION_CODE
        @redirect_uri = parameters[:redirect_uri]
        @code_verifier = parameters[:code_verifier]
        @raw_resource_indicators = parameters[:resource]
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

          token_attributes = custom_token_attributes_with_data
          # RFC 8707 §2.2: audience-restrict the access token to the resources
          # bound to the grant. When the token request specifies a (valid)
          # subset, use that subset; when it omits `resource`, inherit the
          # grant's full resource set so the token is never issued without an
          # audience restriction.
          effective_resources = resolved_resource_indicators.presence || grant_resource_indicators
          if effective_resources.present?
            unless Doorkeeper.config.access_token_model.resource_indicators_supported?
              raise Errors::MissingResourceColumn, "oauth_access_tokens"
            end

            token_attributes[:resource] = effective_resources.join(" ")
          end

          find_or_create_access_token(
            client,
            resource_owner,
            grant.scopes,
            token_attributes,
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

      # RFC 8707: validate resource indicators on the token request.
      # If the grant carries resource indicators, the token request's resource
      # parameter must be a subset. If no grant resource is present, the
      # validator checks the request resource against server policy.
      #
      # Subset and syntax enforcement run even when no validator is configured
      # as long as the grant is already audience-restricted: a grant bound to
      # resources must never be exchanged for a token whose audience widens
      # beyond it. Only when the feature is disabled AND the grant has no
      # stored resources is the `resource` parameter ignored entirely.
      def validate_resource_indicators
        @grant_resource_indicators = grant&.try(:resource)&.split

        validator = Doorkeeper.config.resource_indicator_validator

        # Feature effectively off: no validator and nothing already bound to
        # enforce against. Ignore the `resource` parameter.
        return true if validator.nil? && @grant_resource_indicators.blank?

        @resolved_resource_indicators = ResourceIndicatorValidator.validate!(
          @raw_resource_indicators,
          config_validator: validator,
          client: client,
          grant_resource_indicators: @grant_resource_indicators,
        )
        true
      rescue Errors::InvalidTarget
        false
      end

      def resolved_resource_indicators
        @resolved_resource_indicators || []
      end

      def grant_resource_indicators
        @grant_resource_indicators || []
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
          next if token.nil?

          # With `reuse_access_token` the same token can back several grants
          # (find_or_create returns a shared one). Revoking it on a replay of
          # this grant's code would take down another valid session that still
          # holds it. Only revoke when no other grant references the token, so
          # the single-use revocation reaches a token unique to the replayed
          # code and never collaterally revokes a reused, shared one.
          next if token_shared_with_other_grant?(token)

          token.revoke
        end
      end

      # Reads the grant -> token link, which lives in the optional
      # `oauth_access_grants.access_token_id` column: new installs get it from
      # the generated migration, existing apps add it with the
      # `doorkeeper:grant_reuse_revocation` generator. Callers must therefore
      # guard with `access_token_revoked_on_reuse?` (as
      # `link_access_token_to_grant` and `revoke_token_issued_for_grant` do),
      # so an app that never ran the generator returns early and never queries
      # a column it does not have.
      def token_shared_with_other_grant?(token)
        grant.class
          .where(access_token_id: token.id)
          .where.not(id: grant.id)
          .exists?
      end
    end
  end
end
