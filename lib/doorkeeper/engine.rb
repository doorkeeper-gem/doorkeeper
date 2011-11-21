module Doorkeeper
  class Engine < Rails::Engine
    isolate_namespace Doorkeeper

    config.generators do |g|
      g.test_framework :rspec, :view_specs => false
    end

    initializer "doorkeeper config check" do
      begin
        Doorkeeper.validate_configuration
      rescue Exception => err
        puts err.message
        exit
      end
    end
  end
end
