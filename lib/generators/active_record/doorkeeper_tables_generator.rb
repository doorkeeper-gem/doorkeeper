require 'rails/generators/active_record'

module ActiveRecord
  module Generators
    class DoorkeeperTablesGenerator < ::Rails::Generators::Base
      include Rails::Generators::Migration
      source_root File.expand_path('../templates', __FILE__)

      def copy_default_migration
        migration_template 'doorkeeper_tables.rb', 'db/migrate/create_doorkeeper_tables.rb'
      end

      def self.next_migration_number(dirname)
        ActiveRecord::Generators::Base.next_migration_number(dirname)
      end
    end
  end
end
