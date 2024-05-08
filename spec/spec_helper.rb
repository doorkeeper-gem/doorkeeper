# frozen_string_literal: true

require "coveralls"

Coveralls.wear!("rails") do
  add_filter("/spec/")
  add_filter("/lib/generators/doorkeeper/templates/")
end

ENV["RAILS_ENV"] ||= "test"

$LOAD_PATH.unshift File.dirname(__FILE__)

require "#{File.dirname(__FILE__)}/support/doorkeeper_rspec.rb"

DOORKEEPER_ORM = Doorkeeper::RSpec.detect_orm

require "dummy/config/environment"
require "rspec/rails"
require "capybara/rspec"
require "database_cleaner"
require "generator_spec/test_case"
require "pry-byebug"

# Load JRuby SQLite3 if in that platform
if defined? JRUBY_VERSION
  require "jdbc/sqlite3"
  Jdbc::SQLite3.load_driver
end

Doorkeeper::RSpec.print_configuration_info

require "support/orm/#{DOORKEEPER_ORM}"
require "support/render_with_matcher"

Dir["#{File.dirname(__FILE__)}/support/{dependencies,helpers,shared}/*.rb"].sort.each { |file| require file }

RSpec.configure do |config|
  config.infer_spec_type_from_file_location!
  config.mock_with :rspec

  config.infer_base_class_for_anonymous_controllers = false

  config.include RSpec::Rails::RequestExampleGroup, type: :request

  config.before do
    DatabaseCleaner.start
    Doorkeeper.configure { orm DOORKEEPER_ORM }
  end

  config.after do
    DatabaseCleaner.clean
  end

  config.order = "random"
end
