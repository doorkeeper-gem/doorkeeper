require 'rails/generators/active_record'

class Doorkeeper::PkceGenerator < Rails::Generators::Base
  include Rails::Generators::Migration
  source_root File.expand_path('../templates', __FILE__)
  desc 'Provide support for client application ownership.'

  def application_owner
    migration_template(
      'enable_pkce_migration.rb',
      'db/migrate/enable_pkce.rb'
    )
  end

  def self.next_migration_number(dirname)
    ActiveRecord::Generators::Base.next_migration_number(dirname)
  end
end
