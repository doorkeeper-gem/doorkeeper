require 'rails/generators/active_record'

class Doorkeeper::InstallGenerator < Rails::Generators::Base
  include Rails::Generators::Migration
  source_root File.expand_path('../templates', __FILE__)

  def install
    migration_template 'migration.rb', 'db/migrate/create_doorkeeper_tables.rb'
  end

  def self.next_migration_number(dirname)
    ActiveRecord::Generators::Base.next_migration_number(dirname)
  end
end
