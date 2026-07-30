# frozen_string_literal: true

require "rails/generators"
require "rails/generators/active_record"

module Doorkeeper
  # Generates migration with the `resource` column for access grants and
  # access tokens, required for RFC 8707 Resource Indicators support.
  #
  class ResourceIndicatorsGenerator < ::Rails::Generators::Base
    include ::Rails::Generators::Migration
    source_root File.expand_path("templates", __dir__)
    desc "Add resource indicators support (RFC 8707) to Doorkeeper tables."

    def resource_indicators
      migration_template(
        "enable_resource_indicators_migration.rb.erb",
        "db/migrate/enable_resource_indicators.rb",
        migration_version: migration_version,
      )
    end

    def self.next_migration_number(dirname)
      ActiveRecord::Generators::Base.next_migration_number(dirname)
    end

    private

    def migration_version
      "[#{ActiveRecord::VERSION::MAJOR}.#{ActiveRecord::VERSION::MINOR}]"
    end
  end
end
