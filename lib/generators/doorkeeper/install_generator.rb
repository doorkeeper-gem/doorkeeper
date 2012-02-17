require 'rails/generators/active_record'

class Doorkeeper::InstallGenerator < Rails::Generators::Base
  include Rails::Generators::Migration
  source_root File.expand_path('../templates', __FILE__)
  desc "Installs Doorkeeper."

  def install
    migration_template 'migration.rb', 'db/migrate/create_doorkeeper_tables.rb'
    template "initializer.rb", "config/initializers/doorkeeper.rb"
    copy_file "../../../../config/locales/en.yml", "config/locales/doorkeeper.en.yml"
    route "mount Doorkeeper::Engine => '/oauth'"
    readme "README"
  end

  def self.next_migration_number(dirname)
    ActiveRecord::Generators::Base.next_migration_number(dirname)
  end
end
