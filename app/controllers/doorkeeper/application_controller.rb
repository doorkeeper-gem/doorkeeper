module Doorkeeper
  class ApplicationController < ActionController::Base
    private

    def authenticate_resource!
      redirect_to main_app.root_url unless current_resource_authenticated?
    end

    def current_resource_authenticated?
      !!current_resource
    end

    def current_resource
      instance_eval(&Doorkeeper.resource_owner_authenticator)
    end
  end
end
