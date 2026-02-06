# -*- encoding: utf-8 -*-
# stub: coveralls_reborn 0.29.0 ruby lib

Gem::Specification.new do |s|
  s.name = "coveralls_reborn".freeze
  s.version = "0.29.0"

  s.required_rubygems_version = Gem::Requirement.new(">= 0".freeze) if s.respond_to? :required_rubygems_version=
  s.metadata = { "bug_tracker_uri" => "https://github.com/tagliala/coveralls-ruby-reborn/issues", "changelog_uri" => "https://github.com/tagliala/coveralls-ruby-reborn/blob/main/CHANGELOG.md", "rubygems_mfa_required" => "true", "source_code_uri" => "https://github.com/tagliala/coveralls-ruby-reborn" } if s.respond_to? :metadata=
  s.require_paths = ["lib".freeze]
  s.authors = ["Nick Merwin".freeze, "Wil Gieseler".freeze, "Geremia Taglialatela".freeze]
  s.date = "1980-01-02"
  s.description = "A Ruby implementation of the Coveralls API.".freeze
  s.email = ["nick@lemurheavy.com".freeze, "supapuerco@gmail.com".freeze, "tagliala.dev@gmail.com".freeze]
  s.executables = ["coveralls".freeze]
  s.files = ["bin/coveralls".freeze]
  s.homepage = "https://coveralls.io".freeze
  s.licenses = ["MIT".freeze]
  s.required_ruby_version = Gem::Requirement.new(">= 2.6".freeze)
  s.rubygems_version = "3.4.20".freeze
  s.summary = "A Ruby implementation of the Coveralls API.".freeze

  s.installed_by_version = "3.4.20" if s.respond_to? :installed_by_version

  s.specification_version = 4

  s.add_runtime_dependency(%q<simplecov>.freeze, ["~> 0.22.0"])
  s.add_runtime_dependency(%q<term-ansicolor>.freeze, ["~> 1.7"])
  s.add_runtime_dependency(%q<thor>.freeze, ["~> 1.2"])
  s.add_runtime_dependency(%q<tins>.freeze, ["~> 1.32"])
end
