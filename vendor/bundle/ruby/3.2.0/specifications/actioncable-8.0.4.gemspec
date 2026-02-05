# -*- encoding: utf-8 -*-
# stub: actioncable 8.0.4 ruby lib

Gem::Specification.new do |s|
  s.name = "actioncable".freeze
  s.version = "8.0.4"

  s.required_rubygems_version = Gem::Requirement.new(">= 0".freeze) if s.respond_to? :required_rubygems_version=
  s.metadata = { "bug_tracker_uri" => "https://github.com/rails/rails/issues", "changelog_uri" => "https://github.com/rails/rails/blob/v8.0.4/actioncable/CHANGELOG.md", "documentation_uri" => "https://api.rubyonrails.org/v8.0.4/", "mailing_list_uri" => "https://discuss.rubyonrails.org/c/rubyonrails-talk", "rubygems_mfa_required" => "true", "source_code_uri" => "https://github.com/rails/rails/tree/v8.0.4/actioncable" } if s.respond_to? :metadata=
  s.require_paths = ["lib".freeze]
  s.authors = ["Pratik Naik".freeze, "David Heinemeier Hansson".freeze]
  s.date = "1980-01-02"
  s.description = "Structure many real-time application concerns into channels over a single WebSocket connection.".freeze
  s.email = ["pratiknaik@gmail.com".freeze, "david@loudthinking.com".freeze]
  s.homepage = "https://rubyonrails.org".freeze
  s.licenses = ["MIT".freeze]
  s.required_ruby_version = Gem::Requirement.new(">= 3.2.0".freeze)
  s.rubygems_version = "3.4.20".freeze
  s.summary = "WebSocket framework for Rails.".freeze

  s.installed_by_version = "3.4.20" if s.respond_to? :installed_by_version

  s.specification_version = 4

  s.add_runtime_dependency(%q<activesupport>.freeze, ["= 8.0.4"])
  s.add_runtime_dependency(%q<actionpack>.freeze, ["= 8.0.4"])
  s.add_runtime_dependency(%q<nio4r>.freeze, ["~> 2.0"])
  s.add_runtime_dependency(%q<websocket-driver>.freeze, [">= 0.6.1"])
  s.add_runtime_dependency(%q<zeitwerk>.freeze, ["~> 2.6"])
end
