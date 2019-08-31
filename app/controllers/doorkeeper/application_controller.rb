# frozen_string_literal: true

module Doorkeeper
  class ApplicationController <
    Doorkeeper.configuration.resolve_controller(:base)
    include Helpers::Controller

    unless Doorkeeper.configuration.api_only
      protect_from_forgery with: :exception
      helper "doorkeeper/dashboard"
    end
  end
end
