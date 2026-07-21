# frozen_string_literal: true

module Doorkeeper
  module OAuth
    # Implements the JWT Bearer grant (`urn:ietf:params:oauth:grant-type:jwt-bearer`)
    # profiled by the Identity Assertion Authorization Grant (ID-JAG) draft.
    # Lets this server act as the Resource Authorization Server side of a
    # Cross App Access exchange: it consumes an ID-JAG assertion minted by an
    # external Identity Provider and, once verified, issues a locally-scoped
    # access token.
    #
    # Minting the ID-JAG itself (the IdP side, RFC 8693 Token Exchange) is
    # out of scope for this grant.
    class JwtBearerAccessTokenRequest < BaseRequest
      include OAuth::Helpers

      validate :client, error: Errors::InvalidClient
      validate :client_supports_grant_flow, error: Errors::UnauthorizedClient
      validate :confidential_client, error: Errors::UnauthorizedClient
      validate :assertion_presence, error: Errors::InvalidRequest
      validate :assertion, error: Errors::InvalidGrant
      validate :resource_owner, error: Errors::InvalidGrant
      validate :authorized, error: Errors::InvalidGrant
      validate :scopes, error: Errors::InvalidScope

      attr_reader :client, :assertion, :parameters, :resource_owner, :access_token

      def initialize(server, client, assertion, parameters = {})
        @server          = server
        @client          = client
        @assertion       = assertion
        @parameters      = parameters
        @original_scopes = parameters[:scope]
        @grant_type      = Doorkeeper::OAuth::JWT_BEARER
      end

      private

      def before_successful_response
        create_access_token
        super
      end

      # Per ID-JAG Section 4.4.3 the Resource AS MUST NOT issue a
      # refresh_token when an ID-JAG is exchanged for an access token, so
      # this bypasses `find_or_create_access_token` (whose `use_refresh_token`
      # is derived from the global `refresh_token_enabled?` config, which
      # doesn't special-case grant type) and calls the token model directly,
      # the same way `ClientCredentialsRequest` does.
      def create_access_token
        context = Authorization::Token.build_context(client, grant_type, scopes, resource_owner)

        @access_token = Doorkeeper.config.access_token_model.find_or_create_for(
          application: client&.application,
          resource_owner: resource_owner,
          scopes: scopes,
          expires_in: Authorization::Token.access_token_expires_in(server, context),
          use_refresh_token: false,
        )
      end

      def validate_client
        client.present?
      end

      def validate_client_supports_grant_flow
        Doorkeeper.config.allow_grant_flow_for_client?(grant_type, client&.application)
      end

      # ID-JAG Section 8.1: this grant SHOULD only be supported for
      # confidential clients; public clients SHOULD use the standard
      # authorization code grant instead.
      def validate_confidential_client
        client.confidential || Doorkeeper.config.jwt_bearer_allow_public_clients
      end

      def validate_assertion_presence
        assertion.is_a?(String) && assertion.present?
      end

      # Every assertion-validation failure below funnels into this single
      # boolean, and therefore the same `Errors::InvalidGrant` response - the
      # caller cannot distinguish signature failure from an untrusted issuer
      # from a replayed jti, by design.
      def validate_assertion
        result = Helpers::JwtBearerAssertion.verify(assertion, client: client)
        @claims = result.claims
        result.success?
      end

      def validate_resource_owner
        @resource_owner = Doorkeeper.config.jwt_bearer_resource_owner_from_assertion.call(
          claims["iss"], claims["sub"], client,
        )
        resource_owner.present?
      end

      def validate_authorized
        Doorkeeper.config.jwt_bearer_authorize.call(client, resource_owner, scopes, claims)
      end

      # ID-JAG Section 4.4.1: if the assertion carries a `scope` claim, the
      # issued token's scope MUST be the intersection of that and any
      # `scope` parameter on the token request - the assertion scope is a
      # ceiling the request can narrow but never expand.
      def validate_scopes
        return true if scopes.blank?

        return false if requested_scope.present? && assertion_scope.present? && !assertion_scope.has_scopes?(requested_scope)

        ScopeChecker.valid?(
          scope_str: scopes.to_s,
          server_scopes: server.scopes,
          app_scopes: client.try(:scopes),
          grant_type: grant_type,
        )
      end

      def build_scopes
        return default_scopes if requested_scope.blank? && assertion_scope.blank?
        return assertion_scope if requested_scope.blank?
        return requested_scope if assertion_scope.blank?

        assertion_scope.allowed(requested_scope)
      end

      def requested_scope
        return @requested_scope if defined?(@requested_scope)

        @requested_scope = @original_scopes.present? ? OAuth::Scopes.from_string(@original_scopes) : nil
      end

      def assertion_scope
        return @assertion_scope if defined?(@assertion_scope)

        scope_claim = claims && claims["scope"]
        @assertion_scope = scope_claim.present? ? OAuth::Scopes.from_string(scope_claim) : nil
      end

      attr_reader :claims
    end
  end
end
