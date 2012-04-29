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

  s.files = Dir["{app,config,lib,spec}/**/*"] + ["MIT-LICENSE", "Rakefile", "README.md"]

  s.add_dependency "railties", "~> 3.1"

  s.add_development_dependency "sqlite3", "~> 1.3.5"
  s.add_development_dependency "rspec-rails", "~> 2.9.0"
  s.add_development_dependency "capybara", "~> 1.1.2"
  s.add_development_dependency "generator_spec", "~> 0.8.5"
  s.add_development_dependency "factory_girl_rails", "~> 3.2.0"
  s.add_development_dependency "timecop", "~> 0.3.5"
  s.add_development_dependency "database_cleaner", "~> 0.7.1"
end
