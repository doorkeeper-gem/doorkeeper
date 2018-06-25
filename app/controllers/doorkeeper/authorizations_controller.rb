module Doorkeeper
  class AuthorizationsController < Doorkeeper::ApplicationController
    before_action :authenticate_resource_owner!

    def new
      if pre_auth.authorizable?
        render_success
      else
        render_error
      end
    end

    # TODO: Handle raise invalid authorization
    def create
      redirect_or_render authorize_response
    end

    def destroy
      redirect_or_render authorization.deny
    end

    private

    def render_success
      if skip_authorization? || matching_token?
        redirect_or_render authorize_response
      elsif Doorkeeper.configuration.api_only
        render json: pre_auth
      else
        render :new
      end
    end

    def render_error
      if Doorkeeper.configuration.api_only
        render json: pre_auth.error_response.body[:error_description],
               status: :bad_request
      else
        render :error
      end
    end

    def matching_token?
      token = AccessToken.matching_token_for(
        pre_auth.client,
        current_resource_owner.id,
        pre_auth.scopes
      )

      token && token.accessible?
    end

    def redirect_or_render(auth)
      if auth.redirectable?
        if Doorkeeper.configuration.api_only
          render(
            json: { status: :redirect, redirect_uri: auth.redirect_uri },
            status: auth.status
          )
        else
          redirect_to auth.redirect_uri
        end
      else
        render json: auth.body, status: auth.status
      end
    end

    def pre_auth
      @pre_auth ||= OAuth::PreAuthorization.new(Doorkeeper.configuration,
                                                server.client_via_uid,
                                                params)
    end

    def authorization
      @authorization ||= strategy.request
    end

    def strategy
      @strategy ||= server.authorization_request pre_auth.response_type
    end

    def authorize_response
      @authorize_response ||= begin
        authorizable = pre_auth.authorizable?
        before_successful_authorization if authorizable
        auth = strategy.authorize
        warn_improper_usage
        after_successful_authorization if authorizable
        auth
      end
    end

    def after_successful_authorization
      Doorkeeper.configuration.after_successful_authorization.call(self)
    end

    def before_successful_authorization
      Doorkeeper.configuration.before_successful_authorization.call(self)
    end

    def warn_improper_usage
      return if pre_auth.client.confidential?
      case strategy
      when Request::RefreshToken
        # TODO: suppress warning if refresh token was obtained via PKCE. This
        #       will likely require storing the strategy used to obtain a token
        #       in the database... Useful info in any event
        # TODO: Expose a Doorkeeper.configuration.logger for non-Rails compat.
        # TODO: Don't link to Auth0 but instead helpful Doorkeeper wiki pages
        ::Rails.logger.warn "[Doorkeeper] It is dangerous to allow refresh token strategy on a public/non-confidential application. Please see https://auth0.com/docs/api-auth/which-oauth-flow-to-use"
      when Request::Code
        ::Rails.logger.warn "[Doorkeeper] It is dangerous to use the authorization code strategy on a public/non-confidential application without Proof Key for Code Exchange (PKCE). Please see https://auth0.com/docs/api-auth/which-oauth-flow-to-use"
      end
    end
  end
end
