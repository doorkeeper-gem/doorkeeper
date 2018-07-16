# frozen_string_literal: true

require 'rails/generators'
require 'rails/generators/active_record'

module Doorkeeper
  class PkceGenerator < ::Rails::Generators::Base
    include ::Rails::Generators::Migration
    source_root File.expand_path('templates', __dir__)
    desc 'Provide support for PKCE.'

    def pkce
      migration_template(
        'enable_pkce_migration.rb.erb',
        'db/migrate/enable_pkce.rb',
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
