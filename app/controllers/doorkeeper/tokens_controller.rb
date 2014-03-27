module Doorkeeper
  class TokensController < ::Doorkeeper::ApplicationController
    include Helpers::Controller
    include ActionController::RackDelegation
    include ActionController::Instrumentation

    def create
      response = strategy.authorize
      self.headers.merge! response.headers
      self.response_body = response.body.to_json
      self.status        = response.status
    rescue Errors::DoorkeeperError => e
      handle_token_exception e
    end

    #############################################
    #   RFC 7009 - OAuth 2.0 Token Revocation   #
    #                                           #
    #    http://tools.ietf.org/html/rfc7009     #
    #############################################
    def revoke
      # The authorization server first validates the client credentials
      if doorkeeper_token && doorkeeper_token.accessible?
        # {token_type_hint}  OPTIONAL.  A hint about the type of the token submitted for revocation. 
        # Clients MAY pass this parameter in order to help the authorization server to optimize the token lookup.
        
        if params['token']
          if params['token_type_hint'] == 'refresh_token'
            revoke_refresh_token(params['token']) || revoke_access_token(params['token'])
          elsif params['token_type_hint'] == 'access_token'
            revoke_access_token(params['token']) || revoke_refresh_token(params['token'])
          else
            # If the server is unable to locate the token using the given hint,
            # it MUST extend its search accross all of its supported token types.
            revoke_access_token(params['token']) || revoke_refresh_token(params['token'])
          end
        end
        # The authorization server responds with HTTP status code 200 if the
        # token has been revoked sucessfully or if the client submitted an invalid token
        render json: {}, status: 200
      else
        error = OAuth::ErrorResponse.new(name: :invalid_request)
        render json: error.body, status: error.status
      end
    end

  private

    def revoke_refresh_token(token)
      token = Doorkeeper::AccessToken.by_refresh_token(token)
      if token and doorkeeper_token.same_credential?(token)
        token.revoke
        true
      else
        false
      end
    end

    def revoke_access_token(token)
      token = Doorkeeper::AccessToken.authenticate(token)
      if token and doorkeeper_token.same_credential?(token)
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
