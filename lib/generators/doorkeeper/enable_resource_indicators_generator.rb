# frozen_string_literal: true

require "rails/generators"
require "rails/generators/active_record"

module Doorkeeper
  # Generates migration to add resource indicator support to the
  # doorkeeper tables.
  #
  class EnableResourceIndicatorsGenerator < ::Rails::Generators::Base
    include ::Rails::Generators::Migration
    source_root File.expand_path("templates", __dir__)
    desc "Support Resource Indicators for OAuth 2 (rfc8707)"

    def self.next_migration_number(path)
      ActiveRecord::Generators::Base.next_migration_number(path)
    end

    def previous_refresh_token
      migration_template(
        "add_resource_indicators_to_access_grants_and_access_tokens.rb.erb",
        "db/migrate/add_resource_indicators_to_access_grants_and_access_tokens.rb",
      )
      gsub_file(
        "config/initializers/doorkeeper.rb",
        "# use_resource_indicators",
        "use_resource_indicators",
      )
    end

    private

    def migration_version
      "[#{ActiveRecord::VERSION::MAJOR}.#{ActiveRecord::VERSION::MINOR}]"
    end
  end
end
