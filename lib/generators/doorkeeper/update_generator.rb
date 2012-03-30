require 'rails/generators/active_record'

class Doorkeeper::UpdateGenerator < Rails::Generators::Base
  include Rails::Generators::Migration
  source_root File.expand_path('../templates', __FILE__)
  desc "Updates Doorkeeper Migrations."

  def update
    migration_template 'update_migration.rb', 'db/migrate/add_owner_to_application_table.rb'
  end

  def self.next_migration_number(dirname)
    ActiveRecord::Generators::Base.next_migration_number(dirname)
  end
end
