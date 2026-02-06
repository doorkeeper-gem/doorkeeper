# -*- encoding: utf-8 -*-
# stub: mize 0.6.1 ruby lib

Gem::Specification.new do |s|
  s.name = "mize".freeze
  s.version = "0.6.1"

  s.required_rubygems_version = Gem::Requirement.new(">= 0".freeze) if s.respond_to? :required_rubygems_version=
  s.require_paths = ["lib".freeze]
  s.authors = ["Florian Frank".freeze]
  s.date = "2024-10-17"
  s.description = "Library that provides memoziation for methods and functions for Ruby.".freeze
  s.email = "flori@ping.de".freeze
  s.extra_rdoc_files = ["README.md".freeze, "lib/mize.rb".freeze, "lib/mize/cache_methods.rb".freeze, "lib/mize/cache_protocol.rb".freeze, "lib/mize/configure.rb".freeze, "lib/mize/default_cache.rb".freeze, "lib/mize/global_clear.rb".freeze, "lib/mize/memoize.rb".freeze, "lib/mize/railtie.rb".freeze, "lib/mize/reload.rb".freeze, "lib/mize/version.rb".freeze]
  s.files = ["README.md".freeze, "lib/mize.rb".freeze, "lib/mize/cache_methods.rb".freeze, "lib/mize/cache_protocol.rb".freeze, "lib/mize/configure.rb".freeze, "lib/mize/default_cache.rb".freeze, "lib/mize/global_clear.rb".freeze, "lib/mize/memoize.rb".freeze, "lib/mize/railtie.rb".freeze, "lib/mize/reload.rb".freeze, "lib/mize/version.rb".freeze]
  s.homepage = "https://github.com/flori/mize".freeze
  s.licenses = ["MIT".freeze]
  s.rdoc_options = ["--title".freeze, "Mize - Library that provides memoziation for methods and functions".freeze, "--main".freeze, "README.md".freeze]
  s.required_ruby_version = Gem::Requirement.new(">= 2".freeze)
  s.rubygems_version = "3.4.20".freeze
  s.summary = "Library that provides memoziation for methods and functions".freeze

  s.installed_by_version = "3.4.20" if s.respond_to? :installed_by_version

  s.specification_version = 4

  s.add_development_dependency(%q<gem_hadar>.freeze, ["~> 1.19"])
  s.add_development_dependency(%q<rake>.freeze, [">= 0"])
  s.add_development_dependency(%q<simplecov>.freeze, [">= 0"])
  s.add_development_dependency(%q<rspec>.freeze, [">= 0"])
  s.add_development_dependency(%q<yard>.freeze, [">= 0"])
  s.add_development_dependency(%q<all_images>.freeze, [">= 0"])
  s.add_development_dependency(%q<debug>.freeze, [">= 0"])
end
