# frozen_string_literal: true

require "rails/generators"
require "rails/generators/active_record"

module Doorkeeper
  # Generates migration to add grant_type column to Doorkeeper
  # oauth_access_tokens table.
  #
  class GrantTypeAccessTokensGenerator < ::Rails::Generators::Base
    include ::Rails::Generators::Migration
    source_root File.expand_path("templates", __dir__)
    desc "Add grant_type column to Doorkeeper Access Tokens"

    def grant_type_access_tokens
      migration_template(
        "add_grant_type_to_access_tokens.rb.erb",
        "db/migrate/add_grant_type_to_access_tokens.rb",
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
