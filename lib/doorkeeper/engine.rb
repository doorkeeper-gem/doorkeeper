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

    initializer "doorkeeper.mongoid.models" do
      ActiveSupport.on_load(:mongoid) do
        require "doorkeeper/models/mongoid"
        Mongoid::Document::ClassMethods.send :include, Doorkeeper::Models::Mongoid
      end
    end

    initializer "doorkeeper.mongo_mapper.models" do
      if defined?(MongoMapper)
        require "doorkeeper/models/mongo_mapper"
      end
    end
  end
end
