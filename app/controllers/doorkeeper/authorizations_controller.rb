module Doorkeeper
  class AuthorizationsController < ::Doorkeeper::ApplicationController
    before_filter :authenticate_resource_owner!

    def new
      if authorization.valid?
        if authorization.access_token_exists?
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
    rescue Errors::DoorkeeperError => error
      handle_invalid_request(error)
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
      @strategy ||= server.request params[:response_type]
    end

    def handle_invalid_request(error)
      error_name = case error
        when Errors::InvalidRequestStrategy then :unsupported_response_type
        when Errors::MissingRequestStrategy then :invalid_request
      end

      error = OAuth::ErrorResponse.new :name => error_name, :state => params[:state]
      path  = OAuth::Authorization::URIBuilder.uri_with_query server.client_via_uid.redirect_uri, error.body

      redirect_to path
    end
  end
end
