# frozen_string_literal: true

require "rails/generators"
require "rails/generators/active_record"

module Doorkeeper
  # Generates migration to add the access token reference column to the
  # access grants table, enabling revocation of previously issued tokens
  # when an authorization code is reused (RFC 6749 §4.1.2, §10.5).
  #
  class GrantReuseRevocationGenerator < ::Rails::Generators::Base
    include ::Rails::Generators::Migration
    source_root File.expand_path("templates", __dir__)
    desc "Support revoking issued tokens on authorization code reuse"

    def self.next_migration_number(path)
      ActiveRecord::Generators::Base.next_migration_number(path)
    end

    def grant_reuse_revocation
      return unless no_access_token_id_column?

      migration_template(
        "add_access_token_to_access_grants.rb.erb",
        "db/migrate/add_access_token_to_access_grants.rb",
        migration_version: migration_version,
      )
    end

    private

    def migration_version
      "[#{ActiveRecord::VERSION::MAJOR}.#{ActiveRecord::VERSION::MINOR}]"
    end

    def no_access_token_id_column?
      !ActiveRecord::Base.connection.column_exists?(
        :oauth_access_grants,
        :access_token_id,
      )
    end
  end
end
