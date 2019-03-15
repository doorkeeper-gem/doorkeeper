source "https://rubygems.org"
git_source(:github) { |repo| "https://github.com/#{repo}.git" }

gemspec

gem "rails", "~> 6.0.0.beta3"

# TODO: Remove when rspec-rails 4.0 released
gem "rspec-core", github: "rspec/rspec-core"
gem "rspec-expectations", github: "rspec/rspec-expectations"
gem "rspec-mocks", github: "rspec/rspec-mocks"
gem "rspec-rails", github: "rspec/rspec-rails", branch: "4-0-dev"
gem "rspec-support", github: "rspec/rspec-support"

gem "bcrypt", "~> 3.1", require: false

gem "activerecord-jdbcsqlite3-adapter", platform: :jruby
gem "sqlite3", "~> 1.4", platform: [:ruby, :mswin, :mingw, :x64_mingw]

gem 'tzinfo-data', platforms: [:mingw, :mswin, :x64_mingw]
