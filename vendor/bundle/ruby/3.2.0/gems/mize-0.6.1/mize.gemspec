# -*- encoding: utf-8 -*-
# stub: mize 0.6.1 ruby lib

Gem::Specification.new do |s|
  s.name = "mize".freeze
  s.version = "0.6.1".freeze

  s.required_rubygems_version = Gem::Requirement.new(">= 0".freeze) if s.respond_to? :required_rubygems_version=
  s.require_paths = ["lib".freeze]
  s.authors = ["Florian Frank".freeze]
  s.date = "2024-10-17"
  s.description = "Library that provides memoziation for methods and functions for Ruby.".freeze
  s.email = "flori@ping.de".freeze
  s.extra_rdoc_files = ["README.md".freeze, "lib/mize.rb".freeze, "lib/mize/cache_methods.rb".freeze, "lib/mize/cache_protocol.rb".freeze, "lib/mize/configure.rb".freeze, "lib/mize/default_cache.rb".freeze, "lib/mize/global_clear.rb".freeze, "lib/mize/memoize.rb".freeze, "lib/mize/railtie.rb".freeze, "lib/mize/reload.rb".freeze, "lib/mize/version.rb".freeze]
  s.files = [".all_images.yml".freeze, ".gitignore".freeze, ".rspec".freeze, ".travis.yml".freeze, ".utilsrc".freeze, "CHANGES.md".freeze, "Gemfile".freeze, "LICENSE".freeze, "README.md".freeze, "Rakefile".freeze, "VERSION".freeze, "config/broken_config.yml".freeze, "config/config.yml".freeze, "lib/mize.rb".freeze, "lib/mize/cache_methods.rb".freeze, "lib/mize/cache_protocol.rb".freeze, "lib/mize/configure.rb".freeze, "lib/mize/default_cache.rb".freeze, "lib/mize/global_clear.rb".freeze, "lib/mize/memoize.rb".freeze, "lib/mize/railtie.rb".freeze, "lib/mize/reload.rb".freeze, "lib/mize/version.rb".freeze, "mize.gemspec".freeze, "spec/mize/global_clear_spec.rb".freeze, "spec/mize/memoize_method_spec.rb".freeze, "spec/mize/memoize_reload_spec.rb".freeze, "spec/mize/version_spec.rb".freeze, "spec/spec_helper.rb".freeze]
  s.homepage = "https://github.com/flori/mize".freeze
  s.licenses = ["MIT".freeze]
  s.rdoc_options = ["--title".freeze, "Mize - Library that provides memoziation for methods and functions".freeze, "--main".freeze, "README.md".freeze]
  s.required_ruby_version = Gem::Requirement.new(">= 2".freeze)
  s.rubygems_version = "3.5.18".freeze
  s.summary = "Library that provides memoziation for methods and functions".freeze
  s.test_files = ["spec/mize/global_clear_spec.rb".freeze, "spec/mize/memoize_method_spec.rb".freeze, "spec/mize/memoize_reload_spec.rb".freeze, "spec/mize/version_spec.rb".freeze, "spec/spec_helper.rb".freeze]

  s.specification_version = 4

  s.add_development_dependency(%q<gem_hadar>.freeze, ["~> 1.19".freeze])
  s.add_development_dependency(%q<rake>.freeze, [">= 0".freeze])
  s.add_development_dependency(%q<simplecov>.freeze, [">= 0".freeze])
  s.add_development_dependency(%q<rspec>.freeze, [">= 0".freeze])
  s.add_development_dependency(%q<yard>.freeze, [">= 0".freeze])
  s.add_development_dependency(%q<all_images>.freeze, [">= 0".freeze])
  s.add_development_dependency(%q<debug>.freeze, [">= 0".freeze])
end
