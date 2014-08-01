module Doorkeeper
  class Engine < Rails::Engine
    initializer 'doorkeeper.routes' do
      Doorkeeper::Rails::Routes.warn_if_using_mount_method!
      Doorkeeper::Rails::Routes.install!
    end

    initializer 'doorkeeper.helpers' do
      ActiveSupport.on_load(:action_controller) do
        Doorkeeper.configuration.scopes.each do |s|
          Doorkeeper::Rails::Helpers.define_filter_method(s)
        end

        include Doorkeeper::Rails::Helpers
      end
    end
  end
end
