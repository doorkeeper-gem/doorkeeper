# frozen_string_literal: true

module Doorkeeper
  class Engine < Rails::Engine
    initializer "doorkeeper.routes" do
      Doorkeeper::Rails::Routes.install!
    end

    initializer "doorkeeper.helpers" do
      ActiveSupport.on_load(:action_controller) do
        include Doorkeeper::Rails::Helpers
      end
    end

    config.to_prepare do
      Doorkeeper.run_orm_hooks
    end

    if defined?(Sprockets) && Sprockets::VERSION.chr.to_i >= 4
      initializer "doorkeeper.assets.precompile" do |app|
        # Force users to use:
        #    //= link doorkeeper/admin/application.css
        # in Doorkeeper 5 for Sprockets 4 instead of precompile.
        # Add note to official docs & Wiki
        app.config.assets.precompile += %w[
          doorkeeper/application.css
          doorkeeper/admin/application.css
        ]
      end
    end
  end
end
