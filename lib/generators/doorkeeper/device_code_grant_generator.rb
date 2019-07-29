# frozen_string_literal: true

require "rails/generators"
require "rails/generators/active_record"

module Doorkeeper
  # Generates migration with Device Code required database columns for
  # Doorkeeper tables.
  class DeviceCodeGrantGenerator < ::Rails::Generators::Base
    include ::Rails::Generators::Migration
    source_root File.expand_path("templates", __dir__)
    desc "Provide support for Device Code Grant as drafted in https://tools.ietf.org/html/draft-ietf-oauth-device-flow-15."

    def device_code
      migration_template(
        "enable_device_code_grant_migration.rb.erb",
        "db/migrate/enable_device_code_grant.rb",
        migration_version: migration_version
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
