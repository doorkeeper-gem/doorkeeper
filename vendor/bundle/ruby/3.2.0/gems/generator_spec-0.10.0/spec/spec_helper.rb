require 'bundler/setup'
require 'rspec'
require 'generator_spec'

Dir[Pathname.new(File.expand_path('../', __FILE__)).join('support/**/*.rb')].each {|f| require f}

RSpec.configure do |config|
  config.include Helpers::FileSystem
end
