ENV["RAILS_ENV"] ||= 'test'
DOORKEEPER_ORM = (ENV["DOORKEEPER_ORM"] || :active_record).to_sym

$:.unshift File.dirname(__FILE__)

require 'dummy/config/environment'
require 'rspec/rails'
require 'rspec/autorun'
require 'generator_spec/test_case'
require 'timecop'
require 'database_cleaner'
require "support/orm/#{DOORKEEPER_ORM}"

puts "====> Doorkeeper.orm = #{DOORKEEPER_ORM.inspect}"
puts "====> Rails version: #{Rails.version}"
puts "====> Ruby version: #{RUBY_VERSION}"

ENGINE_RAILS_ROOT = File.join(File.dirname(__FILE__), '../')

Dir["#{File.dirname(__FILE__)}/support/{dependencies,helpers,shared}/*.rb"].each { |f| require f }

RSpec.configure do |config|
  config.mock_with :rspec

  config.infer_base_class_for_anonymous_controllers = false

  config.before do
    DatabaseCleaner.start
    Doorkeeper.configure {}
  end

  config.after do
    DatabaseCleaner.clean
  end
end
