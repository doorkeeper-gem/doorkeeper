# -*- encoding: utf-8 -*-
# stub: mustermann-grape 1.1.0 ruby lib

Gem::Specification.new do |s|
  s.name = "mustermann-grape".freeze
  s.version = "1.1.0"

  s.required_rubygems_version = Gem::Requirement.new(">= 0".freeze) if s.respond_to? :required_rubygems_version=
  s.require_paths = ["lib".freeze]
  s.authors = ["namusyaka".freeze, "Konstantin Haase".freeze, "Daniel Doubrovkine".freeze]
  s.date = "2023-11-24"
  s.description = "Adds Grape style patterns to Mustermman".freeze
  s.email = "namusyaka@gmail.com".freeze
  s.homepage = "https://github.com/ruby-grape/mustermann-grape".freeze
  s.licenses = ["MIT".freeze]
  s.required_ruby_version = Gem::Requirement.new(">= 2.1.0".freeze)
  s.rubygems_version = "3.4.20".freeze
  s.summary = "Grape syntax for Mustermann".freeze

  s.installed_by_version = "3.4.20" if s.respond_to? :installed_by_version

  s.specification_version = 4

  s.add_runtime_dependency(%q<mustermann>.freeze, [">= 1.0.0"])
end
