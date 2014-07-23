$:.push File.expand_path("../lib", __FILE__)

require "doorkeeper/version"

Gem::Specification.new do |s|
  s.name        = "doorkeeper"
  s.version     = Doorkeeper::VERSION
  s.authors     = ["Felipe Elias Philipp", "Piotr Jakubowski"]
  s.email       = ["felipe@applicake.com", "piotr.jakubowski@applicake.com"]
  s.homepage    = "https://github.com/doorkeeper-gem/doorkeeper"
  s.summary     = "Doorkeeper is an OAuth 2 provider for Rails."
  s.description = "Doorkeeper is an OAuth 2 provider for Rails."
  s.license     = 'MIT'

  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- test/*`.split("\n")
  s.require_paths = ["lib"]

  s.add_dependency "railties", ">= 3.1"

  s.add_development_dependency "sqlite3", "~> 1.3.5"
  s.add_development_dependency "rspec-rails", "~> 2.99.0"
  s.add_development_dependency "capybara", "~> 2.3.0"
  s.add_development_dependency "generator_spec", "~> 0.9.0"
  s.add_development_dependency "factory_girl", "~> 4.4.0"
  s.add_development_dependency "timecop", "~> 0.7.0"
  s.add_development_dependency "database_cleaner", "~> 1.3.0"
  s.add_development_dependency "rspec-activemodel-mocks", "~> 1.0.0"
  s.add_development_dependency "bcrypt-ruby", "~> 3.0.1"
  s.add_development_dependency "pry", "~> 0.10.0"
end
