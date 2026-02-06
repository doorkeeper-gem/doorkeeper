# -*- encoding: utf-8 -*-
# stub: dry-core 1.2.0 ruby lib

Gem::Specification.new do |s|
  s.name = "dry-core".freeze
  s.version = "1.2.0"

  s.required_rubygems_version = Gem::Requirement.new(">= 0".freeze) if s.respond_to? :required_rubygems_version=
  s.metadata = { "allowed_push_host" => "https://rubygems.org", "bug_tracker_uri" => "https://github.com/dry-rb/dry-core/issues", "changelog_uri" => "https://github.com/dry-rb/dry-core/blob/main/CHANGELOG.md", "funding_uri" => "https://github.com/sponsors/hanami", "source_code_uri" => "https://github.com/dry-rb/dry-core" } if s.respond_to? :metadata=
  s.require_paths = ["lib".freeze]
  s.authors = ["Hanakai team".freeze]
  s.date = "2025-12-28"
  s.description = "A toolset of small support modules used throughout the dry-rb ecosystem".freeze
  s.email = ["info@hanakai.org".freeze]
  s.extra_rdoc_files = ["README.md".freeze, "CHANGELOG.md".freeze, "LICENSE".freeze]
  s.files = ["CHANGELOG.md".freeze, "LICENSE".freeze, "README.md".freeze]
  s.homepage = "https://dry-rb.org/gems/dry-core".freeze
  s.licenses = ["MIT".freeze]
  s.required_ruby_version = Gem::Requirement.new(">= 3.2".freeze)
  s.rubygems_version = "3.4.20".freeze
  s.summary = "A toolset of small support modules used throughout the dry-rb ecosystem".freeze

  s.installed_by_version = "3.4.20" if s.respond_to? :installed_by_version

  s.specification_version = 4

  s.add_runtime_dependency(%q<concurrent-ruby>.freeze, ["~> 1.0"])
  s.add_runtime_dependency(%q<logger>.freeze, [">= 0"])
  s.add_runtime_dependency(%q<zeitwerk>.freeze, ["~> 2.6"])
  s.add_development_dependency(%q<bundler>.freeze, [">= 0"])
  s.add_development_dependency(%q<rake>.freeze, [">= 0"])
  s.add_development_dependency(%q<rspec>.freeze, [">= 0"])
end
