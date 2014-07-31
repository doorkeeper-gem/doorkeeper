module Doorkeeper
  class ApplicationMetalController < ActionController::Metal
    MODULES = [
      ActionController::RackDelegation,
      ActionController::Instrumentation,
      AbstractController::Rendering,
      ActionController::Rendering,
      ActionController::Renderers::All,
      Helpers::Controller
    ]

    MODULES.each do |mod|
      include mod
    end
  end
end
