require 'rails/generators/active_record'

class Doorkeeper::MigrationGenerator < ::Rails::Generators::Base
  include Rails::Generators::Migration
  source_root File.expand_path('../templates', __FILE__)
  desc 'Installs Doorkeeper migration file.'

  def install
    migration_template 'migration.rb', 'db/migrate/create_doorkeeper_tables.rb'
    rails_v = "#{Rails::VERSION::MAJOR}.#{Rails::VERSION::MINOR}".to_f
    return if rails_v <= 5.0
    migration_file = Dir.entries("db/migrate").select { |file| file[/(\d+)_create_doorkeeper_tables.rb/] }.last
    gsub_file("db/migrate/#{migration_file}", "class CreateDoorkeeperTables < ActiveRecord::Migration",
                                              "class CreateDoorkeeperTables < ActiveRecord::Migration#{[rails_v]}" )
  end

  def self.next_migration_number(dirname)
    ActiveRecord::Generators::Base.next_migration_number(dirname)
  end
end
