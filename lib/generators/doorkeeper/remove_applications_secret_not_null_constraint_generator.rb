# frozen_string_literal: true

require "rails/generators"
require "rails/generators/active_record"

module Doorkeeper
  # Generates migration with which drops NOT NULL constraint and allows not
  # to bloat the database with redundant secret value.
  #
  class RemoveApplicationSecretNotNullConstraint < ::Rails::Generators::Base
    include ::Rails::Generators::Migration
    source_root File.expand_path("templates", __dir__)
    desc "Removes NOT NULL constraint for OAuth2 applications."

    def enable_polymorphic_resource_owner
      migration_template(
        "remove_applications_secret_not_null_constraint.rb.erb",
        "db/migrate/remove_applications_secret_not_null_constraint.rb",
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
