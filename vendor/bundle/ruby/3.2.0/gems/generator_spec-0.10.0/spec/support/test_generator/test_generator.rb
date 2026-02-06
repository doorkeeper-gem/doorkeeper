class TestGenerator < Rails::Generators::Base
  argument :name, :type => :string
  class_option :test, :type => :boolean, :default => false
  source_root File.expand_path('../templates', __FILE__)
  
  def copy_initializer
    template "initializer.rb", "config/initializers/test.rb" if options[:test]
  end
  
  def create_migration
    template "migration.rb", "db/migrate/123_create_tests.rb"
  end
end
