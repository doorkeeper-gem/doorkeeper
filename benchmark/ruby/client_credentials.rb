# frozen_string_literal: true

$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), "..", "..", "lib"))

begin
  require "bundler/inline"
rescue LoadError => e
  warn "Bundler version 1.10 or later is required. Please update your Bundler"
  raise e
end

gemfile(true) do
  source "https://rubygems.org"

  gem "sqlite3"
  gem "rails"
  gem "benchmark-ips"
end

require "benchmark/ips"
require "ostruct"
require "doorkeeper"
require "active_support/all"
require "active_record/railtie"

ActiveRecord::Base.establish_connection(adapter: "sqlite3", database: ":memory:")
ActiveRecord::Base.logger = ENV["LOGGER"].present? ? Logger.new(STDOUT) : nil

# Load database schema
load File.expand_path("../../spec/dummy/db/schema.rb", __dir__)

Doorkeeper.configure do
  orm :active_record

  grant_flows %w[password authorization_code client_credentials]

  skip_authorization do
    true
  end
end

client = Doorkeeper::Application.create!(
  name: "test",
  uid: "123456789",
  secret: "987654321",
  redirect_uri: "https://doorkeeper.test",
)

context = OpenStruct.new
request = OpenStruct.new
request.parameters = {
  client_id: client.uid,
  client_secret: client.secret,
}.with_indifferent_access
context.request = request

Benchmark.ips do |ips|
  ips.report("Client credentials") do
    server = Doorkeeper::Server.new(context)
    strategy = server.token_request("client_credentials")
    strategy.authorize
  end
end
