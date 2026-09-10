# frozen_string_literal: true

require "rails/generators"
require "rails/generators/active_record"

module Doorkeeper
  # Generates migration to add the refresh token scopes column to the
  # database for Doorkeeper tables, so that a refresh token keeps the scope
  # originally granted by the resource owner (RFC 6749 §6) when the access
  # tokens issued with it are narrowed.
  #
  class RefreshTokenScopesGenerator < ::Rails::Generators::Base
    include ::Rails::Generators::Migration
    source_root File.expand_path("templates", __dir__)
    desc "Keep the granted scope on refresh tokens (RFC 6749 §6)"

    def self.next_migration_number(path)
      ActiveRecord::Generators::Base.next_migration_number(path)
    end

    def refresh_token_scopes
      return unless no_refresh_token_scopes_column?

      migration_template(
        "add_refresh_token_scopes_to_access_tokens.rb.erb",
        "db/migrate/add_refresh_token_scopes_to_access_tokens.rb",
      )
    end

    private

    def migration_version
      "[#{ActiveRecord::VERSION::MAJOR}.#{ActiveRecord::VERSION::MINOR}]"
    end

    def no_refresh_token_scopes_column?
      !ActiveRecord::Base.connection.column_exists?(
        :oauth_access_tokens,
        :refresh_token_scopes,
      )
    end
  end
end
