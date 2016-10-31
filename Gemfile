ENV["rails"] ||= "4.2.0"

source "https://rubygems.org"

gem "rails", "~> #{ENV["rails"]}"

if ENV['rails'].start_with?('5')
  gem "rspec-rails", "3.5.2"
end

gem "activerecord-jdbcsqlite3-adapter", platform: :jruby
gem "sqlite3", platform: [:ruby, :mswin, :mingw]

gemspec
