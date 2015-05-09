module Doorkeeper
  class Engine < Rails::Engine
    initializer "doorkeeper.params.filter" do |app|
      app.config.filter_parameters += [:client_secret, :code, :token]
    end

    initializer "doorkeeper.locales" do |app|
      if app.config.i18n.fallbacks.blank?
        app.config.i18n.fallbacks = [:en]
      end
    end

    initializer "doorkeeper.routes" do
      Doorkeeper::Rails::Routes.install!
    end

    initializer "doorkeeper.helpers" do
      ActiveSupport.on_load(:action_controller) do
        include Doorkeeper::Rails::Helpers
      end
    end
  end
end
