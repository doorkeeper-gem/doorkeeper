# frozen_string_literal: true

module Doorkeeper
  class ApplicationController <
    Doorkeeper.config.resolve_controller(:base)
    include Helpers::Controller
    include ActionController::MimeResponds if Doorkeeper.config.api_only

    unless Doorkeeper.config.api_only
      protect_from_forgery with: :exception
      helper "doorkeeper/dashboard"
    end
  end
end
