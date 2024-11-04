# frozen_string_literal: true

source "https://rubygems.org"
git_source(:github) { |repo| "https://github.com/#{repo}.git" }

gemspec

gem "rails", ">= 6.0", "< 7.3"

gem "sprockets-rails"

gem "rspec-core"
gem "rspec-expectations"
gem "rspec-mocks"
gem "rspec-rails", "~> 7.0"
gem "rspec-support"

gem "rubocop", "~> 1.4"
gem "rubocop-performance", require: false
gem "rubocop-rails", require: false
gem "rubocop-rspec", require: false

gem "bcrypt", "~> 3.1", require: false

gem "activerecord-jdbcsqlite3-adapter", platform: :jruby
gem "sqlite3", "~> 2.2", platform: [:ruby, :mswin, :mingw, :x64_mingw]

gem "tzinfo-data", platforms: %i[mingw mswin x64_mingw]
gem "timecop"

gem 'irb', '~> 1.8'

# Interactive Debugging tools
gem 'debug', '~> 1.8'
