module Doorkeeper
  class AuthorizationsController < ::Doorkeeper::ApplicationController
    before_filter :authenticate_resource_owner!

    def new
      if authorization.valid?      	
        if authorization.access_token_exists? || skip_authorization!
          auth = authorization.authorize
          if authorization.success_redirect_uri.present?
            redirect_to authorization.success_redirect_uri
          else
            redirect_to oauth_authorization_code_path(:code => auth.token)
          end
        end
      elsif authorization.redirect_on_error?
        redirect_to authorization.invalid_redirect_uri
      else
        @error = authorization.error_response.body
        render :error
      end
    rescue Errors::DoorkeeperError => e
      handle_authorization_exception e
    end

    def show
    end

    def create
      if auth = authorization.authorize
        if authorization.success_redirect_uri.present?
          redirect_to authorization.success_redirect_uri
        else
          redirect_to oauth_authorization_code_path(:code => auth.token)
        end
      elsif authorization.redirect_on_error?
        redirect_to authorization.invalid_redirect_uri
      else
        @error = authorization.error_response
        render :error
      end
    end

    def destroy
      authorization.deny
      redirect_to authorization.invalid_redirect_uri
    end

  private

    def authorization
      @authorization ||= strategy.request
    end

    def strategy
      @strategy ||= server.authorization_request params[:response_type]
    end
  end
end
