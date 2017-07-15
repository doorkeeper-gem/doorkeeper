require 'rails/generators/active_record'

class Doorkeeper::MigrationGenerator < ::Rails::Generators::Base
  include Rails::Generators::Migration
  source_root File.expand_path('../templates', __FILE__)
  desc 'Installs Doorkeeper migration file.'

  def install
    migration_template 'migration.rb', 'db/migrate/create_doorkeeper_tables.rb', migration_version: migration_version
  end

  def self.next_migration_number(dirname)
    ActiveRecord::Generators::Base.next_migration_number(dirname)
  end

  def rails5?
    Rails.version.start_with? '5'
  end

  def migration_version
   if rails5?
     "[#{Rails::VERSION::MAJOR}.#{Rails::VERSION::MINOR}]"
   end
  end
end
