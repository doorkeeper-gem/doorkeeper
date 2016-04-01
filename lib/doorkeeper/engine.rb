module Doorkeeper
  class Engine < Rails::Engine
    initializer "doorkeeper.params.filter" do |app|
      parameters = %w(client_secret code authentication_token access_token refresh_token)
      app.config.filter_parameters << /^(#{Regexp.union parameters})$/
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
