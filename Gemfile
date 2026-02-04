# frozen_string_literal: true

source "https://rubygems.org"
git_source(:github) { |repo| "https://github.com/#{repo}.git" }

gemspec

gem "rails", ">= 7.0", "< 8.1"

gem "sprockets-rails"

gem "rspec-core"
gem "rspec-expectations"
gem "rspec-mocks"
gem "rspec-rails", "~> 8.0"
gem "rspec-support"

gem "rubocop", "~> 1.72"
gem "rubocop-capybara", "~> 2.22", require: false
gem "rubocop-factory_bot", "~> 2.27", require: false
gem "rubocop-performance", "~> 1.24", require: false
gem "rubocop-rails", "~> 2.30", require: false
gem "rubocop-rspec", "~> 3.5", require: false
gem "rubocop-rspec_rails", "~> 2.31", require: false

gem "bcrypt", "~> 3.1", require: false

gem "activerecord-jdbcsqlite3-adapter", platform: :jruby
gem "sqlite3", "~> 2.3", platform: [:ruby, :mswin, :mingw, :x64_mingw]

gem "tzinfo-data", platforms: %i[mingw mswin x64_mingw]
gem "timecop"

gem 'irb', '~> 1.8'

# Interactive Debugging tools
gem 'debug', '~> 1.8'
