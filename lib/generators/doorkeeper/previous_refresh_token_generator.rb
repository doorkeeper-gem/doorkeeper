require 'rails/generators/active_record'

module Doorkeeper
  class PreviousRefreshTokenGenerator < Rails::Generators::Base
    include Rails::Generators::Migration
    source_root File.expand_path('../templates', __FILE__)
    desc 'Support revoke refresh token on access token use'

    def self.next_migration_number(path)
      ActiveRecord::Generators::Base.next_migration_number(path)
    end

    def previous_refresh_token
      if !previous_refresh_token_column_exists?
        migration_template(
          'add_previous_refresh_token_to_access_tokens.rb',
          'db/migrate/add_previous_refresh_token_to_access_tokens.rb'
        )
      end
    end

    private

    def previous_refresh_token_column_exists?
      ActiveRecord::Base.connection.column_exists?(
        :oauth_access_tokens,
        :previous_refresh_token
      )
    end
  end
end
