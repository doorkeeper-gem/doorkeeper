# frozen_string_literal: true

module Doorkeeper
  class TokensController < Doorkeeper::ApplicationMetalController
    def create
      headers.merge!(authorize_response.headers)
      render json: authorize_response.body,
             status: authorize_response.status
    rescue Errors::DoorkeeperError => e
      handle_token_exception(e)
    end

    # OAuth 2.0 Token Revocation - http://tools.ietf.org/html/rfc7009
    def revoke
      # The authorization server, if applicable, first authenticates the client
      # and checks its ownership of the provided token. Check #authorized? for
      # more details.

      if authorized?
        revoke_token
        # @see 2.2.  Revocation Response
        #
        # The authorization server responds with HTTP status code 200 if the token
        # has been revoked successfully or if the client submitted an invalid
        # token.
        render json: {}, status: 200
      else
        render json: revocation_error_response, status: :forbidden
      end
    end

    def introspect
      introspection = OAuth::TokenIntrospection.new(server, token)

      if introspection.authorized?
        render json: introspection.to_json, status: 200
      else
        error = introspection.error_response
        headers.merge!(error.headers)
        render json: error.body, status: error.status
      end
    end

    private

    # OAuth 2.0 Section 2.1 defines two client types, "public" & "confidential".
    # Public clients (as per RFC 7009) do not require authentication whereas
    # confidential clients must be authenticated for their token revocation.
    #
    # Once a confidential client is authenticated, it must be authorized to
    # revoke the provided access or refresh token. This ensures one client
    # cannot revoke another's tokens.
    #
    # Doorkeeper determines the client type implicitly via the presence of the
    # OAuth client associated with a given access or refresh token. Since public
    # clients authenticate the resource owner via "password" or "implicit" grant
    # types, they set the application_id as null (since the claim cannot be
    # verified).
    #
    # https://tools.ietf.org/html/rfc6749#section-2.1
    # https://tools.ietf.org/html/rfc7009
    def authorized?
      return unless token.present?

      # Client is confidential, therefore client authentication & authorization
      # is required
      if token.application_id? && token.application.confidential?
        # We authorize client by checking token's application
        server.client && server.client.application == token.application
      else
        # Client is public, authentication unnecessary
        true
      end
    end

    def revoke_token
      # The authorization server responds with HTTP status code 200 if the token
      # has been revoked successfully or if the client submitted an invalid
      # token
      token.revoke if token&.accessible?
    end

    # Doorkeeper does not use the token_type_hint logic described in the
    # RFC 7009 due to the refresh token implementation that is a field in
    # the access token model.
    def token
      @token ||= Doorkeeper.config.access_token_model.by_token(params["token"]) ||
                 Doorkeeper.config.access_token_model.by_refresh_token(params["token"])
    end

    def strategy
      @strategy ||= server.token_request(params[:grant_type])
    end

    def authorize_response
      @authorize_response ||= begin
        before_successful_authorization
        auth = strategy.authorize
        after_successful_authorization unless auth.is_a?(Doorkeeper::OAuth::ErrorResponse)
        auth
      end
    end

    def after_successful_authorization
      Doorkeeper.configuration.after_successful_authorization.call(self)
    end

    def before_successful_authorization
      Doorkeeper.configuration.before_successful_authorization.call(self)
    end

    def revocation_error_response
      error_description = I18n.t(:unauthorized, scope: %i[doorkeeper errors messages revoke])

      { error: :unauthorized_client, error_description: error_description }
    end
  end
end
