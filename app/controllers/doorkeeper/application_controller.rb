module Doorkeeper
  class ApplicationController < ActionController::Base
    include Helpers::Controller

  private

    def server
      @server ||= Server.new(self)
    end

    def get_error_response_from_exception(exception)
      error_name = case exception
      when Errors::InvalidTokenStrategy
        :unsupported_grant_type
      when Errors::InvalidAuthorizationStrategy
        :unsupported_response_type
      when Errors::MissingRequestStrategy
        :invalid_request
      end

      OAuth::ErrorResponse.new :name => error_name, :state => params[:state]
    end

    def handle_authorization_exception(exception)
      error = get_error_response_from_exception exception
      url   = OAuth::Authorization::URIBuilder.uri_with_query server.client_via_uid.redirect_uri, error.body
      redirect_to url
    end

    def handle_token_exception(exception)
      error = get_error_response_from_exception exception
      render :json => error.body, :status => error.status
    end
  end
end
