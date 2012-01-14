ENV["RAILS_ENV"] ||= 'test'
require File.expand_path("../dummy/config/environment", __FILE__)

require 'rspec/rails'
require 'rspec/autorun'
require 'generator_spec/test_case'
require 'timecop'

ENGINE_RAILS_ROOT = File.join(File.dirname(__FILE__), '../')

# load schema to in memory sqlite
ActiveRecord::Migration.verbose = false
load Rails.root + "db/schema.rb"

Dir[File.join(ENGINE_RAILS_ROOT, "spec/support/**/*.rb")].each { |f| require f }

RSpec.configure do |config|
  config.mock_with :rspec

  config.infer_base_class_for_anonymous_controllers = false

  config.before do
    Doorkeeper.configure {}
  end
end
