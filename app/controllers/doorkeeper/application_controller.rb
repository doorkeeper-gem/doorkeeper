module Doorkeeper
  class ApplicationController < ActionController::Base
    private

    def authenticate_resource_owner!
      current_resource_owner
    end

    def current_resource_owner
      instance_exec(main_app, &Doorkeeper.configuration.authenticate_resource_owner)
    end

    def resource_owner_from_credentials
      instance_exec(main_app, &Doorkeeper.configuration.resource_owner_from_credentials)
    end

    def authenticate_admin!
      if block = Doorkeeper.configuration.authenticate_admin
        instance_exec(main_app, &block)
      end
    end
  end
end
