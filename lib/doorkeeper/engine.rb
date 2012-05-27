module Doorkeeper
  class Engine < Rails::Engine
    isolate_namespace Doorkeeper

    config.generators do |g|
      g.test_framework :rspec, :view_specs => false
    end

    initializer "doorkeeper.deprecations" do
      if Doorkeeper.installed?
        if Doorkeeper.configuration.authorization_scopes.present?
          warning = <<-WARN
[DOORKEEPER]
  Configuration for `authorization_scopes` will no longer be supported. Use default_scopes/optional_scopes instead.
  ATTENTION: The :description option could not be migrated because doorkeeper now uses localization files.
  Place this in your config/locales/en.yml
en:
  doorkeeper:
    scopes:
WARN
          puts warning
          Doorkeeper.configuration.authorization_scopes.translations.each do |scope, translation|
            puts "      #{scope}: #{translation}"
          end
        end

        if Doorkeeper::AccessToken.columns_hash["resource_owner_id"].null == false
          warn <<-WARN
[DOORKEEPER]
  In order to use the Client Credentials flow, you have to migrate the oauth_access_tokens table:
  change_column :oauth_access_tokens, :resource_owner_id, :integer, :null => true
WARN
        end
      end
    end

    initializer "doorkeeper.helpers" do
      ActiveSupport.on_load(:action_controller) do
        include Doorkeeper::Helpers::Filter
      end
    end
  end
end
