# frozen_string_literal: true

module Doorkeeper
  class ApplicationMetalController < ActionController::Metal
    MODULES = [
      ActionController::Instrumentation,
      AbstractController::Rendering,
      ActionController::Rendering,
      ActionController::Renderers::All,
      AbstractController::Callbacks,
      Helpers::Controller
    ].freeze

    MODULES.each do |mod|
      include mod
    end

    before_action :enforce_content_type,
                  if: -> { Doorkeeper.configuration.enforce_content_type }

    ActiveSupport.run_load_hooks(:doorkeeper_metal_controller, self)
  end
end
