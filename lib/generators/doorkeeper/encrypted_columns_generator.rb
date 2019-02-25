# frozen_string_literal: true

require 'rails/generators'
require 'rails/generators/active_record'

module Doorkeeper
  class EncryptedColumnsGenerator < ::Rails::Generators::Base
    include ::Rails::Generators::Migration
    source_root File.expand_path('templates', __dir__)
    desc 'Add encrypted columns to Doorkeeper applications'

    def pkce
      migration_template(
        'add_encrypted_columns.rb.erb',
        'db/migrate/add_encrypted_columns.rb',
        migration_version: migration_version
      )
    end

    def self.next_migration_number(dirname)
      ActiveRecord::Generators::Base.next_migration_number(dirname)
    end

    private

    def migration_version
      if ActiveRecord::VERSION::MAJOR >= 5
        "[#{ActiveRecord::VERSION::MAJOR}.#{ActiveRecord::VERSION::MINOR}]"
      end
    end
  end
end
