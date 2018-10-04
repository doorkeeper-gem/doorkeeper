# frozen_string_literal: true

module Doorkeeper
  class ApplicationController <
    Doorkeeper.configuration.base_controller.constantize

    include Helpers::Controller

    unless Doorkeeper.configuration.api_only
      protect_from_forgery with: :exception
      helper 'doorkeeper/dashboard'
    end
  end
end
