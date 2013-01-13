require 'rails/generators/active_record'

module ActiveRecord
  module Generators
    class DoorkeeperClientGenerator < ActiveRecord::Generators::Base
      argument :attributes, :type => :array, :default => [], :banner => "field:type field:type"
      source_root File.expand_path('../templates', __FILE__)

      def copy_migration
        if model_exists?
          migration_template "migration_existing.rb", "db/migrate/add_doorkeeper_client_to_#{table_name}"
        else
          migration_template "migration.rb", "db/migrate/create_doorkeeper_client_as_#{table_name}"
        end
      end

      def generate_model
        invoke "active_record:model", [name], :migration => false unless model_exists?
      end

      def inject_doorkeeper_content
        content =
<<-CONTENT
  # Setup doorkeeper client extension
  doorkeeper_client!

  attr_accessible :name, :redirect_uri
CONTENT

        inject_into_class model_path, class_name, content if model_exists?
      end

    private

      def model_exists?
        File.exists?(File.join(destination_root, model_path))
      end

      def model_path
        @model_path ||= File.join("app", "models", "#{file_path}.rb")
      end
    end
  end
end
