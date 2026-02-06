# -*- encoding: utf-8 -*-
# stub: generator_spec 0.10.0 ruby lib

Gem::Specification.new do |s|
  s.name = "generator_spec".freeze
  s.version = "0.10.0"

  s.required_rubygems_version = Gem::Requirement.new(">= 0".freeze) if s.respond_to? :required_rubygems_version=
  s.require_paths = ["lib".freeze]
  s.authors = ["Steve Hodgkiss".freeze]
  s.date = "2024-01-25"
  s.description = "Test Rails generators with RSpec".freeze
  s.email = ["steve@hodgkiss.me.uk".freeze]
  s.homepage = "https://github.com/stevehodgkiss/generator_spec".freeze
  s.licenses = ["MIT".freeze]
  s.rubygems_version = "3.4.20".freeze
  s.summary = "Test Rails generators with RSpec".freeze

  s.installed_by_version = "3.4.20" if s.respond_to? :installed_by_version

  s.specification_version = 4

  s.add_runtime_dependency(%q<activesupport>.freeze, [">= 3.0.0"])
  s.add_runtime_dependency(%q<railties>.freeze, [">= 3.0.0"])
  s.add_development_dependency(%q<rspec>.freeze, ["~> 3.0"])
end
