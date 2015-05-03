$:.push File.expand_path("../lib", __FILE__)

require "doorkeeper/version"

Gem::Specification.new do |s|
  s.name        = "doorkeeper"
  s.version     = Doorkeeper::VERSION
  s.authors     = ["Felipe Elias Philipp", "Tute Costa"]
  s.email       = %w(tutecosta@gmail.com)
  s.homepage    = "https://github.com/doorkeeper-gem/doorkeeper"
  s.summary     = "OAuth 2 provider for Rails and Grape"
  s.description = "Doorkeeper is an OAuth 2 provider for Rails and Grape."
  s.license     = 'MIT'

  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- spec/*`.split("\n")
  s.require_paths = ["lib"]

  s.add_dependency "railties", ">= 3.2"

  s.add_development_dependency "sqlite3", "~> 1.3.5"
  s.add_development_dependency "rspec-rails", "~> 3.2.0"
  s.add_development_dependency "capybara", "~> 2.3.0"
  s.add_development_dependency "generator_spec", "~> 0.9.0"
  s.add_development_dependency "factory_girl", "~> 4.5.0"
  s.add_development_dependency "timecop", "~> 0.7.0"
  s.add_development_dependency "database_cleaner", "~> 1.3.0"
end
