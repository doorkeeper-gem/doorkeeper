require 'mongoid/version'

Mongoid.configure do |config|
  config.master = Mongo::Connection.new('127.0.0.1', 27017).db("doorkeeper-test-suite")
  # config.use_utc = true
end

DatabaseCleaner[:mongoid].strategy = :truncation
DatabaseCleaner[:mongoid].clean_with :truncation
