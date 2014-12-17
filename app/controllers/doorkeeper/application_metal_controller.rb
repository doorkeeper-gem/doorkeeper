module Doorkeeper
  class ApplicationMetalController < ActionController::Metal
    MODULES = [
      ActionController::RackDelegation,
      ActionController::Instrumentation,
      AbstractController::Rendering,
      ActionController::Rendering,
      ActionController::Renderers::All,
      ActionController::RequestForgeryProtection,
      Helpers::Controller
    ]

    MODULES.each do |mod|
      include mod
    end

    if ::Rails.version.to_i < 4
      protect_from_forgery
    else
      protect_from_forgery with: :exception
    end
  end
end
