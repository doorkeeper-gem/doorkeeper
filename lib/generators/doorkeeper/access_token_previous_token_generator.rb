require 'rails/generators/active_record'

class Doorkeeper::AccessTokenPreviousTokenGenerator < Rails::Generators::Base
  include Rails::Generators::Migration
  source_root File.expand_path('../templates', __FILE__)
  desc 'Provide support for revoking previous refresh token on new access token first use.'

  def access_token_previous_token
    if oauth_access_tokens_exists? && !previous_token_column_exists?
      migration_template(
        'add_previous_refresh_token_to_access_tokens.rb',
        'db/migrate/add_previous_refresh_token_to_access_tokens.rb'
      )
    end
  end

  def self.next_migration_number(dirname)
    ActiveRecord::Generators::Base.next_migration_number(dirname)
  end

  private

  def previous_token_column_exists?
    ActiveRecord::Base.connection.column_exists?(
      :oauth_access_tokens,
      :previous_refresh_token
    )
  end

  # Might be running this before install
  def oauth_access_tokens_exists?
    ActiveRecord::Base.connection.table_exists? :oauth_access_tokens
  end
end
