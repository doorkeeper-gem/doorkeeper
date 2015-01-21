require 'rails/generators/active_record'

class Doorkeeper::AccessTokenPreviousTokenGenerator < Rails::Generators::Base
  include Rails::Generators::Migration
  source_root File.expand_path('../templates', __FILE__)
  desc 'Provide support for revoking previous refresh token on new access token first use.'

  def previous_refresh_token
    migration_template(
      'add_previous_refresh_token_to_access_tokens.rb',
      'db/migrate/add_previous_refresh_token_to_access_tokens.rb'
    )
  end

  def self.next_migration_number(dirname)
    ActiveRecord::Generators::Base.next_migration_number(dirname)
  end
end
