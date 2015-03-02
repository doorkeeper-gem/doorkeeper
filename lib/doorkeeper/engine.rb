module Doorkeeper
  class Engine < Rails::Engine
    initializer "doorkeeper.params.filter" do |app|
      app.config.filter_parameters += [:client_secret, :code, :token]
    end

    initializer 'doorkeeper.routes' do
      Doorkeeper::Rails::Routes.warn_if_using_mount_method!
      Doorkeeper::Rails::Routes.install!
    end

    initializer 'doorkeeper.helpers' do
      ActiveSupport.on_load(:action_controller) do
        include Doorkeeper::Helpers::Filter
      end
    end
  end
end
