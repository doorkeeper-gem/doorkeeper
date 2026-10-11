# frozen_string_literal: true

require "rails/generators"
require "rails/generators/active_record"

module Doorkeeper
  # Generates migration to add the refresh token revocation column to the
  # database for Doorkeeper tables, so that a refresh token can be revoked
  # without revoking the access token stored on the same record (see the
  # +revoke_previous_access_token_on_refresh+ configuration option).
  #
  class RefreshTokenRevokedAtGenerator < ::Rails::Generators::Base
    include ::Rails::Generators::Migration
    source_root File.expand_path("templates", __dir__)
    desc "Allow refresh tokens to be revoked separately from their access token"

    def self.next_migration_number(path)
      ActiveRecord::Generators::Base.next_migration_number(path)
    end

    def refresh_token_revoked_at
      return unless no_refresh_token_revoked_at_column?

      migration_template(
        "add_refresh_token_revoked_at_to_access_tokens.rb.erb",
        "db/migrate/add_refresh_token_revoked_at_to_access_tokens.rb",
      )
    end

    private

    def migration_version
      "[#{ActiveRecord::VERSION::MAJOR}.#{ActiveRecord::VERSION::MINOR}]"
    end

    def no_refresh_token_revoked_at_column?
      !ActiveRecord::Base.connection.column_exists?(
        :oauth_access_tokens,
        :refresh_token_revoked_at,
      )
    end
  end
end
