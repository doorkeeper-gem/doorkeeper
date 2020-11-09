# frozen_string_literal: true

source "https://rubygems.org"
git_source(:github) { |repo| "https://github.com/#{repo}.git" }

gemspec

gem "rails", "~> 6.0"

gem "rspec-core"
gem "rspec-expectations"
gem "rspec-mocks"
gem "rspec-rails", "~> 4.0"
gem "rspec-support"

gem "rubocop", "~> 1.2"
gem "rubocop-performance", require: false
gem "rubocop-rails", require: false
gem "rubocop-rspec", require: false

gem "bcrypt", "~> 3.1", require: false

gem "activerecord-jdbcsqlite3-adapter", platform: :jruby
gem "sqlite3", "~> 1.4", platform: %i[ruby mswin mingw x64_mingw]

gem "tzinfo-data", platforms: %i[mingw mswin x64_mingw]
