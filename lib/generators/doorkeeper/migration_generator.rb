require 'rails/generators/active_record'

class Doorkeeper::MigrationGenerator < ::Rails::Generators::Base
  include Rails::Generators::Migration
  source_root File.expand_path('../templates', __FILE__)
  desc 'Installs Doorkeeper migration file.'

  def install
    @migration_version = Rails::VERSION::STRING[0..2].to_f
    migration_template(
      "migration.rb.erb",
      "db/migrate/create_doorkeeper_tables.rb"
    )
  end

  def self.next_migration_number(dirname)
    ActiveRecord::Generators::Base.next_migration_number(dirname)
  end

  def migration_version
    if Rails.version >= "5.0.0"
      "[#{Rails::VERSION::MAJOR}.#{Rails::VERSION::MINOR}]"
    end
  end
end
