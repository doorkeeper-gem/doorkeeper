ENV['RAILS_ENV'] ||= 'test'
DOORKEEPER_ORM = (ENV['orm'] || :active_record).to_sym
TABLE_NAME_PREFIX = ENV['table_name_prefix'] || nil
TABLE_NAME_SUFFIX = ENV['table_name_suffix'] || nil

$LOAD_PATH.unshift File.dirname(__FILE__)

require 'capybara/rspec'
require 'rspec/active_model/mocks'
require 'dummy/config/environment'
require 'rspec/rails'
require 'rspec/autorun'
require 'generator_spec/test_case'
require 'timecop'
require 'database_cleaner'

Rails.logger.info "====> Doorkeeper.orm = #{Doorkeeper.configuration.orm.inspect}"
if Doorkeeper.configuration.orm == :active_record
  Rails.logger.info "======> active_record.table_name_prefix = #{Rails.configuration.active_record.table_name_prefix.inspect}"
  Rails.logger.info "======> active_record.table_name_suffix = #{Rails.configuration.active_record.table_name_suffix.inspect}"
end
Rails.logger.info "====> Rails version: #{Rails.version}"
Rails.logger.info "====> Ruby version: #{RUBY_VERSION}"

require "support/orm/#{Doorkeeper.configuration.orm_name}"

ENGINE_RAILS_ROOT = File.join(File.dirname(__FILE__), '../')

Dir["#{File.dirname(__FILE__)}/support/{dependencies,helpers,shared}/*.rb"].each { |f| require f }

RSpec.configure do |config|
  config.infer_spec_type_from_file_location!
  config.mock_with :rspec

  config.infer_base_class_for_anonymous_controllers = false

  config.before do
    DatabaseCleaner.start
    Doorkeeper.configure { orm DOORKEEPER_ORM }
  end

  config.after do
    DatabaseCleaner.clean
  end

  config.order = 'random'
end
