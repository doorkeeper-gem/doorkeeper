module Doorkeeper
  class Engine < Rails::Engine
    isolate_namespace Doorkeeper

    config.generators do |g|
      g.test_framework :rspec, :view_specs => false
    end
  end
end
