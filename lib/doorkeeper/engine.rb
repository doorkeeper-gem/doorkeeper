module Doorkeeper
  class Engine < Rails::Engine
    isolate_namespace Doorkeeper

    config.generators do |g|
      g.test_framework :rspec, :view_specs => false
    end

    initializer "doorkeeper.deprecations" do
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
    end
  end
end
