# -*- encoding: utf-8 -*-
# stub: grape 3.1.1 ruby lib

Gem::Specification.new do |s|
  s.name = "grape".freeze
  s.version = "3.1.1"

  s.required_rubygems_version = Gem::Requirement.new(">= 0".freeze) if s.respond_to? :required_rubygems_version=
  s.metadata = { "bug_tracker_uri" => "https://github.com/ruby-grape/grape/issues", "changelog_uri" => "https://github.com/ruby-grape/grape/blob/v3.1.1/CHANGELOG.md", "documentation_uri" => "https://www.rubydoc.info/gems/grape/3.1.1", "rubygems_mfa_required" => "true", "source_code_uri" => "https://github.com/ruby-grape/grape/tree/v3.1.1" } if s.respond_to? :metadata=
  s.require_paths = ["lib".freeze]
  s.authors = ["Michael Bleigh".freeze]
  s.date = "1980-01-02"
  s.description = "A Ruby framework for rapid API development with great conventions.".freeze
  s.email = ["michael@intridea.com".freeze]
  s.homepage = "https://github.com/ruby-grape/grape".freeze
  s.licenses = ["MIT".freeze]
  s.required_ruby_version = Gem::Requirement.new(">= 3.1".freeze)
  s.rubygems_version = "3.4.20".freeze
  s.summary = "A simple Ruby framework for building REST-like APIs.".freeze

  s.installed_by_version = "3.4.20" if s.respond_to? :installed_by_version

  s.specification_version = 4

  s.add_runtime_dependency(%q<activesupport>.freeze, [">= 7.1"])
  s.add_runtime_dependency(%q<dry-configurable>.freeze, [">= 0"])
  s.add_runtime_dependency(%q<dry-types>.freeze, [">= 1.1"])
  s.add_runtime_dependency(%q<mustermann-grape>.freeze, ["~> 1.1.0"])
  s.add_runtime_dependency(%q<rack>.freeze, [">= 2"])
  s.add_runtime_dependency(%q<zeitwerk>.freeze, [">= 0"])
end
