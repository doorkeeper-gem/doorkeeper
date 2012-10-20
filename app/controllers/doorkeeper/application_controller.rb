module Doorkeeper
  class ApplicationController < ActionController::Base
    include Helpers::Controller

  private

    def server
      @server ||= Server.new(self)
    end
  end
end
