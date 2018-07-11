$LOAD_PATH.push File.expand_path("../lib", __FILE__)

require "doorkeeper/version"

Gem::Specification.new do |s|
  s.name        = "doorkeeper"
  s.version     = Doorkeeper.gem_version
  s.authors     = ["Felipe Elias Philipp", "Tute Costa", "Jon Moss", "Nikita Bulai"]
  s.email       = %w(bulaj.nikita@gmail.com)
  s.homepage    = "https://github.com/doorkeeper-gem/doorkeeper"
  s.summary     = "OAuth 2 provider for Rails and Grape"
  s.description = "Doorkeeper is an OAuth 2 provider for Rails and Grape."
  s.license     = 'MIT'

  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- spec/*`.split("\n")
  s.require_paths = ["lib"]

  s.add_dependency "railties", ">= 4.2"
  s.required_ruby_version = ">= 2.1"

  s.add_development_dependency "capybara"
  s.add_development_dependency "coveralls"
  s.add_development_dependency "grape"
  s.add_development_dependency "database_cleaner", "~> 1.6"
  s.add_development_dependency "factory_bot", "~> 4.8"
  s.add_development_dependency "generator_spec", "~> 0.9.3"
  s.add_development_dependency "rake", ">= 11.3.0"
  s.add_development_dependency "rspec-rails"

  s.post_install_message = %q{


  WARNING: This is a security release that addresses token revocation not working for public apps (CVE-2018-1000211)

  There is no breaking change in this release, however to take advantage of the security fix you must:

    1. Run `rails generate doorkeeper:add_client_confidentiality` for the migration
    2. Review your OAuth apps and determine which ones exclusively use public grant flows (eg implicit)
    3. Update their `confidential` column to `false` for those public apps

  This is a backported security release.

  For more information:

    * https://github.com/doorkeeper-gem/doorkeeper/pull/1119
    * https://github.com/doorkeeper-gem/doorkeeper/issues/891



  }
end
