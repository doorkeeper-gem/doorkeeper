module Doorkeeper
  class Engine < Rails::Engine
    initializer "doorkeeper.routes" do
      Doorkeeper::Rails::Routes.warn_if_using_mount_method!
      Doorkeeper::Rails::Routes.install!
    end

    initializer "doorkeeper.helpers" do
      ActiveSupport.on_load(:action_controller) do
        include Doorkeeper::Helpers::Filter
      end
    end

    initializer "doorkeeper.active_record.models" do
      ActiveSupport.on_load(:active_record) do
        require 'doorkeeper/models/active_record'
        extend Doorkeeper::Models::ActiveRecord
      end
    end
  end
end
