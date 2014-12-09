require 'rails/generators/active_record'

class Doorkeeper::ApplicationScopesGenerator < Rails::Generators::Base
  include Rails::Generators::Migration
  source_root File.expand_path('../templates', __FILE__)
  desc 'Copies ActiveRecord migrations to handle upgrade to doorkeeper 2'

  def self.next_migration_number(path)
    ActiveRecord::Generators::Base.next_migration_number(path)
  end

  def application_scopes
    if oauth_applications_exists? && !scopes_column_exists?
      migration_template(
        'add_scopes_to_oauth_applications.rb',
        'db/migrate/add_scopes_to_oauth_applications.rb'
      )
    end
  end

  private

  def scopes_column_exists?
    ActiveRecord::Base.connection.column_exists?(
      :oauth_applications,
      :scopes
    )
  end

  # Might be running this before install
  def oauth_applications_exists?
    ActiveRecord::Base.connection.table_exists? :oauth_applications
  end
end
