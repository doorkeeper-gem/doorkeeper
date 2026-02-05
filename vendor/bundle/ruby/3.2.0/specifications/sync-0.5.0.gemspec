# -*- encoding: utf-8 -*-
# stub: sync 0.5.0 ruby lib

Gem::Specification.new do |s|
  s.name = "sync".freeze
  s.version = "0.5.0"

  s.required_rubygems_version = Gem::Requirement.new(">= 0".freeze) if s.respond_to? :required_rubygems_version=
  s.require_paths = ["lib".freeze]
  s.authors = ["Keiju ISHITSUKA".freeze]
  s.bindir = "exe".freeze
  s.date = "2018-12-04"
  s.description = "A module that provides a two-phase lock with a counter.".freeze
  s.email = ["keiju@ruby-lang.org".freeze]
  s.homepage = "https://github.com/ruby/sync".freeze
  s.licenses = ["BSD-2-Clause".freeze]
  s.rubygems_version = "3.4.20".freeze
  s.summary = "A module that provides a two-phase lock with a counter.".freeze

  s.installed_by_version = "3.4.20" if s.respond_to? :installed_by_version

  s.specification_version = 4

  s.add_development_dependency(%q<bundler>.freeze, [">= 0"])
  s.add_development_dependency(%q<rake>.freeze, [">= 0"])
  s.add_development_dependency(%q<test-unit>.freeze, [">= 0"])
end
