# frozen_string_literal: true

require "rails/generators"
require "rails/generators/active_record"

module Doorkeeper
  # Generates migration to add the refresh token family column to the
  # database for Doorkeeper tables, so that revoking a refresh token reaches
  # every token issued from the same authorization grant (RFC 7009 §2.1).
  #
  class RefreshTokenFamilyIdGenerator < ::Rails::Generators::Base
    include ::Rails::Generators::Migration
    source_root File.expand_path("templates", __dir__)
    desc "Track refresh token families for grant-level revocation (RFC 7009 §2.1)"

    def self.next_migration_number(path)
      ActiveRecord::Generators::Base.next_migration_number(path)
    end

    def refresh_token_family_id
      return unless no_refresh_token_family_id_column?

      migration_template(
        "add_refresh_token_family_id_to_access_tokens.rb.erb",
        "db/migrate/add_refresh_token_family_id_to_access_tokens.rb",
      )
    end

    private

    def migration_version
      "[#{ActiveRecord::VERSION::MAJOR}.#{ActiveRecord::VERSION::MINOR}]"
    end

    def no_refresh_token_family_id_column?
      !ActiveRecord::Base.connection.column_exists?(
        :oauth_access_tokens,
        :refresh_token_family_id,
      )
    end
  end
end
