ENV["rails"] ||= "4.2.0"

source "https://rubygems.org"

gem "rails", "~> #{ENV["rails"]}"

if ENV["rails"] == "5.0.0.beta1"
  gem "capybara", github: "jnicklas/capybara"
end

gem "activerecord-jdbcsqlite3-adapter", platform: :jruby
gem "sqlite3", platform: [:ruby, :mswin, :mingw]

gemspec
