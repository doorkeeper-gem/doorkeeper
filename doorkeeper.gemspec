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

  s.files = Dir["{app,config,db,lib}/**/*"] + ["MIT-LICENSE", "Rakefile", "README.md"]

  s.add_dependency "rails", ">= 3.1.1", "< 4.0"

  s.add_development_dependency "sqlite3"
  s.add_development_dependency "rspec-rails"
  s.add_development_dependency "capybara"
  s.add_development_dependency "generator_spec"
  s.add_development_dependency "factory_girl_rails"
  s.add_development_dependency "timecop"
  s.add_development_dependency "database_cleaner"
end
