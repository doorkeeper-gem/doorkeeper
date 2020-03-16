# frozen_string_literal: true

source "https://rubygems.org"
git_source(:github) { |repo| "https://github.com/#{repo}.git" }

gemspec

gem "rails", "~> 6.0.0"

# TODO: Remove when rspec-rails 4.0 released
gem "rspec-core", github: "rspec/rspec-core"
gem "rspec-expectations", github: "rspec/rspec-expectations"
gem "rspec-mocks", github: "rspec/rspec-mocks"
gem "rspec-rails", "4.0.0.rc1"
gem "rspec-support", github: "rspec/rspec-support"

gem "rubocop", "~> 0.75"
gem "rubocop-performance"

gem "bcrypt", "~> 3.1", require: false

gem "activerecord-jdbcsqlite3-adapter", platform: :jruby
gem "sqlite3", "~> 1.4", platform: %i[ruby mswin mingw x64_mingw]

gem "tzinfo-data", platforms: %i[mingw mswin x64_mingw]
