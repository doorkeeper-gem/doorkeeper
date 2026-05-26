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

    # Drain any queued `on_load(:active_record)` callbacks (including the one
    # `run_orm_hooks` registers above) from `config.after_initialize`.
    #
    # `to_prepare` runs *before* `after_initialize` in Rails finishers, so by
    # the time this block fires AR's own `:set_configs` after_initialize has
    # already applied framework defaults from `new_framework_defaults_*.rb`
    # (#1703). Touching `::ActiveRecord::Base` here loads AR in that
    # known-clean context, firing the queued callbacks before any host-app
    # code (e.g. `rails db:seed`) can autoload models and trigger the
    # callbacks re-entrantly from inside `class ApplicationRecord <
    # ActiveRecord::Base` (#1828).
    initializer "doorkeeper.orm.flush_active_record_hooks", after: "active_record.set_configs" do
      config.after_initialize do
        ::ActiveRecord::Base if defined?(::ActiveRecord)
      end
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
