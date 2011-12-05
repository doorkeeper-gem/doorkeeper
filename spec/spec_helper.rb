ENV["RAILS_ENV"] ||= 'test'
require File.expand_path("../dummy/config/environment", __FILE__)

require 'rspec/rails'
require 'rspec/autorun'
require 'generator_spec/test_case'
require 'timecop'
require 'factory_girl_rails'
FactoryGirl.definition_file_paths << File.join(File.dirname(__FILE__), 'factories')
FactoryGirl.find_definitions

require "database_cleaner"

ENGINE_RAILS_ROOT = File.join(File.dirname(__FILE__), '../')

# load schema to in memory sqlite
load Rails.root + "db/schema.rb"

Dir[File.join(ENGINE_RAILS_ROOT, "spec/support/**/*.rb")].each { |f| require f }

RSpec.configure do |config|
  config.mock_with :rspec

  config.before(:suite) do
    DatabaseCleaner.strategy = :transaction
    DatabaseCleaner.clean_with(:truncation)
  end

  config.before(:each) do
    DatabaseCleaner.start
  end

  config.after(:each) do
    DatabaseCleaner.clean
    Doorkeeper.configure {}
  end

  config.infer_base_class_for_anonymous_controllers = false

  config.include RequestSpecHelper,          :type => :request
  config.include AuthorizationRequestHelper, :type => :request
  config.include AccessTokenRequestHelper,   :type => :request
end
