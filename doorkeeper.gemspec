$:.push File.expand_path("../lib", __FILE__)

require "doorkeeper/version"

Gem::Specification.new do |s|
  s.name        = "doorkeeper"
  s.version     = Doorkeeper::VERSION
  s.authors     = ["Felipe Elias Philipp", "Piotr Jakubowski"]
  s.email       = ["felipe@applicake.com", "piotr.jakubowski@applicake.com"]
  s.homepage    = "https://github.com/applicake/doorkeeper"
  s.summary     = "Doorkeeper is an OAuth 2 provider for Rails."
  s.description = "Doorkeeper is an OAuth 2 provider for Rails."
  s.license     = 'MIT'

  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- test/*`.split("\n")
  s.require_paths = ["lib"]

  s.add_dependency "railties", ">= 3.1"
  s.add_dependency "jquery-rails", ">= 2.0.2"

  s.add_development_dependency "sqlite3", "~> 1.3.5"
  s.add_development_dependency "rspec-rails", ">= 2.11.4"
  s.add_development_dependency "capybara", "~> 1.1.2"
  s.add_development_dependency "generator_spec", "~> 0.9.0"
  s.add_development_dependency "factory_girl", "~> 2.6.4"
  s.add_development_dependency "timecop", "~> 0.5.2"
  s.add_development_dependency "database_cleaner", "~> 0.9.1"
  s.add_development_dependency "bcrypt-ruby", "~> 3.0.1"
end
