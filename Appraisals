# frozen_string_literal: true

appraise "rails-5-2" do
  gem "rails", "~> 5.2.0"
  gem "sqlite3", "~> 1.3", "< 1.4", platform: %i[ruby mswin mingw x64_mingw]
end

appraise "rails-6-0" do
  gem "rails", "~> 6.0.0"
  gem "sqlite3", "~> 1.4", platform: %i[ruby mswin mingw x64_mingw]
end

appraise "rails-6-1" do
  gem "rails", "~> 6.1.0"
  gem "sqlite3", "~> 1.4", platform: %i[ruby mswin mingw x64_mingw]
end

appraise "rails-7-0" do
  gem "rails", "~> 7.0.0alpha1"
  gem "sqlite3", "~> 1.4", platform: %i[ruby mswin mingw x64_mingw]
end

appraise "rails-main" do
  gem "rails", git: "https://github.com/rails/rails"
  gem "sqlite3", "~> 1.4", platform: %i[ruby mswin mingw x64_mingw]
end
