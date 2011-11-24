module Doorkeeper
  class ApplicationController < ActionController::Base
    private

    def authenticate_resource_owner!
      current_resource_owner
    end

    def current_resource_owner
      instance_eval(&Doorkeeper.authenticate_resource_owner)
    end

    def authenticate_admin!
      if block = Doorkeeper.authenticate_admin
        instance_eval(&block)
      end
    end

    def method_missing(method, *args, &block)
      if method =~ /_(url|path)$/
        raise "Your path has not been found. Didn't you mean to call main_app.#{method} in doorkeeper configuration block?"
      else
        super
      end
    end
  end
end
