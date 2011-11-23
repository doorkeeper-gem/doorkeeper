module Doorkeeper
  class ApplicationController < ActionController::Base
    private

    def authenticate_resource_owner!
      current_resource_owner
    end

    def current_resource_owner
      instance_eval(&Doorkeeper.authenticate_resource_owner)
    end
  end
end
