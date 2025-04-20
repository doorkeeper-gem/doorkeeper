# frozen_string_literal: true

module Doorkeeper
  module OAuth
    # RFC7662 OAuth 2.0 Token Introspection
    #
    # @see https://datatracker.ietf.org/doc/html/rfc7662
    class TokenIntrospection
      attr_reader :token, :error, :invalid_request_reason

      def initialize(server, token)
        @server = server
        @token = token
      end

      def authorized?
        authorize!
        @error.blank?
      end

      def error_response
        return if @error.blank?

        if @error == Errors::InvalidToken
          OAuth::InvalidTokenResponse.from_access_token(authorized_token)
        elsif @error == Errors::InvalidRequest
          OAuth::InvalidRequestResponse.from_request(self)
        else
          OAuth::ErrorResponse.from_request(self)
        end
      end

      def to_json(*)
        active? ? success_response : failure_response
      end

      private

      attr_reader :server

      # If the protected resource uses OAuth 2.0 client credentials to
      # authenticate to the introspection endpoint and its credentials are
      # invalid, the authorization server responds with an HTTP 401
      # (Unauthorized) as described in Section 5.2 of OAuth 2.0 [RFC6749].
      #
      # Endpoint must first validate the authentication.
      # If the authentication is invalid, the endpoint should respond with
      # an HTTP 401 status code and an invalid_client response.
      #
      # @see https://www.oauth.com/oauth2-servers/token-introspection-endpoint/
      #
      # To prevent token scanning attacks, the endpoint MUST also require
      # some form of authorization to access this endpoint, such as client
      # authentication as described in OAuth 2.0 [RFC6749] or a separate
      # OAuth 2.0 access token such as the bearer token described in OAuth
      # 2.0 Bearer Token Usage [RFC6750].
      #
      def authorize!
        # Requested client authorization
        if server.credentials
          authorize_using_basic_auth!
        elsif authorized_token
          authorize_using_bearer_token!
        else
          @error = Errors::InvalidRequest
          @invalid_request_reason = :request_not_authorized
        end
      end

      def authorize_using_basic_auth!
        # Note that a properly formed and authorized query for an inactive or
        # otherwise invalid token (or a token the protected resource is not
        # allowed to know about) is not considered an error response by this
        # specification. In these cases, the authorization server MUST instead
        # respond with an introspection response with the "active" field set to
        # "false" as described in Section 2.2.
        @error = Errors::InvalidClient unless authorized_client
      end

      def authorize_using_bearer_token!
        # Requested bearer token authorization
        #
        #  If the protected resource uses an OAuth 2.0 bearer token to authorize
        #  its call to the introspection endpoint and the token used for
        #  authorization does not contain sufficient privileges or is otherwise
        #  invalid for this request, the authorization server responds with an
        #  HTTP 401 code as described in Section 3 of OAuth 2.0 Bearer Token
        #  Usage [RFC6750].
        #
        @error = Errors::InvalidToken unless valid_authorized_token?
      end

      # Client Authentication
      def authorized_client
        @authorized_client ||= server.credentials && server.client
      end

      # Bearer Token Authentication
      def authorized_token
        @authorized_token ||= Doorkeeper.authenticate(server.context.request)
      end

      # 2.2. Introspection Response
      def success_response
        customize_response(
          active: true,
          scope: @token.scopes_string,
          client_id: @token.try(:application).try(:uid),
          token_type: @token.token_type,
          exp: @token.expires_at.to_i,
          iat: @token.created_at.to_i,
        )
      end

      # If the introspection call is properly authorized but the token is not
      # active, does not exist on this server, or the protected resource is
      # not allowed to introspect this particular token, then the
      # authorization server MUST return an introspection response with the
      # "active" field set to "false".  Note that to avoid disclosing too
      # much of the authorization server's state to a third party, the
      # authorization server SHOULD NOT include any additional information
      # about an inactive token, including why the token is inactive.
      #
      # @see https://datatracker.ietf.org/doc/html/rfc7662 2.2. Introspection Response
      #
      def failure_response
        {
          active: false,
        }
      end

      # Boolean indicator of whether or not the presented token
      # is currently active.  The specifics of a token's "active" state
      # will vary depending on the implementation of the authorization
      # server and the information it keeps about its tokens, but a "true"
      # value return for the "active" property will generally indicate
      # that a given token has been issued by this authorization server,
      # has not been revoked by the resource owner, and is within its
      # given time window of validity (e.g., after its issuance time and
      # before its expiration time).
      #
      # Any other error is considered an "inactive" token.
      #
      # * The token requested does not exist or is invalid
      # * The token expired
      # * The token was issued to a different client than is making this request
      #
      # Since resource servers using token introspection rely on the
      # authorization server to determine the state of a token, the
      # authorization server MUST perform all applicable checks against a
      # token's state. For instance, these tests include the following:
      #
      #    o  If the token can expire, the authorization server MUST determine
      #       whether or not the token has expired.
      #    o  If the token can be issued before it is able to be used, the
      #       authorization server MUST determine whether or not a token's valid
      #       period has started yet.
      #    o  If the token can be revoked after it was issued, the authorization
      #       server MUST determine whether or not such a revocation has taken
      #       place.
      #    o  If the token has been signed, the authorization server MUST
      #       validate the signature.
      #    o  If the token can be used only at certain resource servers, the
      #       authorization server MUST determine whether or not the token can
      #       be used at the resource server making the introspection call.
      #
      def active?
        if authorized_client
          valid_token? && token_introspection_allowed?(auth_client: authorized_client.application)
        else
          valid_token?
        end
      end

      # Token can be valid only if it is not expired or revoked.
      def valid_token?
        @token&.accessible?
      end

      def valid_authorized_token?
        !authorized_token_matches_introspected? &&
          authorized_token.accessible? &&
          token_introspection_allowed?(auth_token: authorized_token)
      end

      # RFC7662 Section 2.1
      def authorized_token_matches_introspected?
        authorized_token.token == @token&.token
      end

      # Config constraints for introspection in Doorkeeper.config.allow_token_introspection
      def token_introspection_allowed?(auth_client: nil, auth_token: nil)
        allow_introspection = Doorkeeper.config.allow_token_introspection
        return allow_introspection unless allow_introspection.respond_to?(:call)

        allow_introspection.call(@token, auth_client, auth_token)
      end

      # Allows to customize introspection response.
      # Provides context (controller) and token for generating developer-specific
      # response.
      #
      # @see https://datatracker.ietf.org/doc/html/rfc7662#section-2.2
      #
      def customize_response(response)
        customized_response = Doorkeeper.config.custom_introspection_response.call(
          token,
          server.context,
        )
        return response if customized_response.blank?

        response.merge(customized_response)
      end
    end
  end
end
