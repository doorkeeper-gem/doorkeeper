module Doorkeeper
  class AuthorizationsController < ApplicationController
    before_filter :authenticate_resource!

    rescue_from OAuth::MismatchRedirectURI do
      Rails.logger.error "OAuth: Invalid application redirect_uri"
      render :error
    end

    def new
      @authorization = OAuth::AuthorizationRequest.new(current_resource, params)
      render :error unless @authorization.valid?
    end

    def create
      authorization = OAuth::AuthorizationRequest.new(current_resource, params)
      if authorization.authorize
        redirect_to authorization.redirect_uri
      else
        redirect_to authorization.invalid_redirect_uri
      end
    end
  end
end
