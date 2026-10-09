# frozen_string_literal: true

require "rails/generators"
require "rails/generators/active_record"

module Doorkeeper
  # Generates migration with the `old_secret` and `old_secret_created_at`
  # columns for applications, required by the `enable_secret_rotation` option.
  #
  class SecretRotationGenerator < ::Rails::Generators::Base
    include ::Rails::Generators::Migration
    source_root File.expand_path("templates", __dir__)
    desc "Add client secret rotation support to Doorkeeper applications."

    def secret_rotation
      migration_template(
        "enable_secret_rotation_migration.rb.erb",
        "db/migrate/enable_secret_rotation.rb",
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
