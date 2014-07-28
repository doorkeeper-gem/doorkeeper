module Doorkeeper
  class TokensController < Doorkeeper::ApplicationMetalController
    def create
      response = strategy.authorize
      self.headers.merge! response.headers
      self.response_body = response.body.to_json
      self.status        = response.status
    rescue Errors::DoorkeeperError => e
      handle_token_exception e
    end

    # OAuth 2.0 Token Revocation - http://tools.ietf.org/html/rfc7009
    def revoke
      # The authorization server first validates the client credentials
      if doorkeeper_token && doorkeeper_token.accessible?
        # Doorkeeper does not use the token_type_hint logic described in the RFC 7009
        # due to the refresh token implementation that is a field in the access token model.
        revoke_token(request.POST['token']) if request.POST['token']
      end
      # The authorization server responds with HTTP status code 200 if the
      # token has been revoked sucessfully or if the client submitted an invalid token
      render json: {}, status: 200
    end

    private

    def revoke_token(token)
      token = AccessToken.authenticate(token) || AccessToken.by_refresh_token(token)
      if token && doorkeeper_token.same_credential?(token)
        token.revoke
        true
      else
        false
      end
    end

    def strategy
      @strategy ||= server.token_request params[:grant_type]
    end
  end
end
