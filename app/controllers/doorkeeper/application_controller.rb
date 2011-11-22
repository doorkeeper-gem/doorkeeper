module Doorkeeper
  class ApplicationController < ActionController::Base
    private

    def authenticate_resource!
      current_resource
    end

    def current_resource
      instance_eval(&Doorkeeper.authenticate_resource_owner)
    end
  end
end
