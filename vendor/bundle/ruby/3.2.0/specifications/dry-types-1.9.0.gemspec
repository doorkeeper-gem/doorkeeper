# -*- encoding: utf-8 -*-
# stub: dry-types 1.9.0 ruby lib

Gem::Specification.new do |s|
  s.name = "dry-types".freeze
  s.version = "1.9.0"

  s.required_rubygems_version = Gem::Requirement.new(">= 0".freeze) if s.respond_to? :required_rubygems_version=
  s.metadata = { "allowed_push_host" => "https://rubygems.org", "bug_tracker_uri" => "https://github.com/dry-rb/dry-types/issues", "changelog_uri" => "https://github.com/dry-rb/dry-types/blob/main/CHANGELOG.md", "funding_uri" => "https://github.com/sponsors/hanami", "source_code_uri" => "https://github.com/dry-rb/dry-types" } if s.respond_to? :metadata=
  s.require_paths = ["lib".freeze]
  s.authors = ["Hanakai team".freeze]
  s.date = "1980-01-02"
  s.description = "Type system for Ruby supporting coercions, constraints and complex types like structs, value objects, enums etc".freeze
  s.email = ["info@hanakai.org".freeze]
  s.extra_rdoc_files = ["CHANGELOG.md".freeze, "LICENSE".freeze, "README.md".freeze]
  s.files = ["CHANGELOG.md".freeze, "LICENSE".freeze, "README.md".freeze]
  s.homepage = "https://dry-rb.org/gems/dry-types".freeze
  s.licenses = ["MIT".freeze]
  s.required_ruby_version = Gem::Requirement.new(">= 3.2".freeze)
  s.rubygems_version = "3.4.20".freeze
  s.summary = "Type system for Ruby supporting coercions, constraints and complex types like structs, value objects, enums etc".freeze

  s.installed_by_version = "3.4.20" if s.respond_to? :installed_by_version

  s.specification_version = 4

  s.add_runtime_dependency(%q<bigdecimal>.freeze, [">= 3.0"])
  s.add_runtime_dependency(%q<concurrent-ruby>.freeze, ["~> 1.0"])
  s.add_runtime_dependency(%q<dry-core>.freeze, ["~> 1.0"])
  s.add_runtime_dependency(%q<dry-inflector>.freeze, ["~> 1.0"])
  s.add_runtime_dependency(%q<dry-logic>.freeze, ["~> 1.4"])
  s.add_runtime_dependency(%q<zeitwerk>.freeze, ["~> 2.6"])
  s.add_development_dependency(%q<bundler>.freeze, [">= 0"])
  s.add_development_dependency(%q<rake>.freeze, [">= 0"])
  s.add_development_dependency(%q<rspec>.freeze, [">= 0"])
  s.add_development_dependency(%q<yard>.freeze, [">= 0"])
end
