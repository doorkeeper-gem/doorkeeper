# frozen_string_literal: true

module Doorkeeper
  class Engine < Rails::Engine
    initializer "doorkeeper.params.filter", after: :load_config_initializers do |app|
      app.config.to_prepare do
        Doorkeeper.setup_filter_parameters
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

    config.to_prepare do
      Doorkeeper.run_orm_hooks
    end

    # After every to_prepare block rather than inside this engine's, which
    # runs before the host application's: the Mongoid extension defines
    # Doorkeeper::Application only from run_orm_hooks above, so a host
    # declaring the attribute on it has nowhere earlier than its own
    # to_prepare to do so, and asking before that would report an attribute
    # missing that is about to be declared.
    config.after_initialize do
      Doorkeeper.warn_missing_client_id_metadata_column
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
