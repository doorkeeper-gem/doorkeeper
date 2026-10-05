# frozen_string_literal: true

require "rails/generators"
require "rails/generators/active_record"

module Doorkeeper
  # Generates migration with the column that marks applications written from
  # a client ID metadata document (use_client_id_metadata_documents).
  #
  class ClientIdMetadataDocumentsGenerator < ::Rails::Generators::Base
    include ::Rails::Generators::Migration
    source_root File.expand_path("templates", __dir__)
    desc "Add client ID metadata document support to Doorkeeper applications."

    def client_id_metadata_documents
      migration_template(
        "add_client_id_metadata_materialized_at_to_applications_migration.rb.erb",
        "db/migrate/add_client_id_metadata_materialized_at_to_applications.rb",
        migration_version: migration_version,
      )
    end

    def self.next_migration_number(dirname)
      ActiveRecord::Generators::Base.next_migration_number(dirname)
    end

    private

    def migration_version
      "[#{ActiveRecord::VERSION::MAJOR}.#{ActiveRecord::VERSION::MINOR}]"
    end
  end
end
