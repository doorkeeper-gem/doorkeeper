module Doorkeeper
  class ApplicationController < ActionController::Base
    private

    def authenticate_resource_owner!
      current_resource_owner
    end

    def current_resource_owner
      instance_exec(main_app, &Doorkeeper.authenticate_resource_owner)
    end

    def authenticate_admin!
      if block = Doorkeeper.authenticate_admin
        instance_exec(main_app, &block)
      end
    end

    def method_missing(method, *args, &block)
      if method =~ /_(url|path)$/
        raise "Your path has not been found. Didn't you mean to call routes.#{method} in doorkeeper configuration blocks?"
      else
        super
      end
    end
  end
end
