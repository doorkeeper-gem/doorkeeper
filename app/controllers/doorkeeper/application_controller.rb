# frozen_string_literal: true

module Doorkeeper
  class ApplicationController <
    Doorkeeper.config.resolve_controller(:base)
    include Helpers::Controller
    include ActionController::MimeResponds if Doorkeeper.config.api_only

    skip_forgery_protection

    unless Doorkeeper.config.api_only
      helper "doorkeeper/dashboard"
    end
  end
end
