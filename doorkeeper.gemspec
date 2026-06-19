# frozen_string_literal: true

$LOAD_PATH.unshift(File.expand_path("lib", __dir__))

require "doorkeeper/version"

Gem::Specification.new do |gem|
  gem.name        = "doorkeeper"
  gem.version     = Doorkeeper::VERSION::STRING
  gem.authors     = ["Felipe Elias Philipp", "Tute Costa", "Jon Moss", "Nikita Bulai"]
  gem.email       = %w[bulaj.nikita@gmail.com]
  gem.homepage    = "https://github.com/doorkeeper-gem/doorkeeper"
  gem.summary     = "OAuth 2 provider for Rails and Grape"
  gem.description = "Doorkeeper is an OAuth 2 provider for Rails and Grape."
  gem.license     = "MIT"

  gem.files = Dir[
    "{app,config,lib,vendor}/**/*",
    "CHANGELOG.md",
    "MIT-LICENSE",
    "README.md",
  ]
  gem.require_paths = ["lib"]

  gem.metadata = {
    "homepage_uri" => "https://github.com/doorkeeper-gem/doorkeeper",
    "changelog_uri" => "https://github.com/doorkeeper-gem/doorkeeper/blob/main/CHANGELOG.md",
    "source_code_uri" => "https://github.com/doorkeeper-gem/doorkeeper",
    "bug_tracker_uri" => "https://github.com/doorkeeper-gem/doorkeeper/issues",
    "documentation_uri" => "https://doorkeeper.gitbook.io/guides/",
    "funding_uri" => "https://opencollective.com/doorkeeper-gem",
  }

  gem.add_dependency "railties", ">= 5"
  gem.required_ruby_version = ">= 2.7"

  gem.add_development_dependency "appraisal"
  gem.add_development_dependency "capybara"
  gem.add_development_dependency "coveralls_reborn"
  gem.add_development_dependency "database_cleaner", "~> 2.0"
  gem.add_development_dependency "factory_bot", "~> 6.0"
  gem.add_development_dependency "generator_spec", "~> 0.10.0"
  gem.add_development_dependency "grape"
  gem.add_development_dependency "rake", ">= 11.3.0"
  gem.add_development_dependency "rspec-rails"
  gem.add_development_dependency "timecop"
end
