module Doorkeeper
  class AuthorizationsController < ApplicationController
    before_filter :authenticate_resource_owner!

    def new
      @authorization = OAuth::AuthorizationRequest.new(current_resource_owner, params)
      render :error unless @authorization.valid?
    end

    def create
      @authorization = OAuth::AuthorizationRequest.new(current_resource_owner, params)
      if @authorization.authorize
        redirect_to @authorization.success_redirect_uri
      else
        render :error
      end
    end
  end
end
