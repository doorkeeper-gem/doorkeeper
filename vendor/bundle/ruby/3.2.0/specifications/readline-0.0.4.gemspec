# -*- encoding: utf-8 -*-
# stub: readline 0.0.4 ruby lib

Gem::Specification.new do |s|
  s.name = "readline".freeze
  s.version = "0.0.4"

  s.required_rubygems_version = Gem::Requirement.new(">= 0".freeze) if s.respond_to? :required_rubygems_version=
  s.require_paths = ["lib".freeze]
  s.authors = ["aycabta".freeze]
  s.date = "2023-12-16"
  s.description = "This is just a loader for \"readline\". If Ruby has the \"readline-ext\" gem\nthat is a native extension, this gem will load it. If Ruby does not have\nthe \"readline-ext\" gem this gem will load \"reline\", a library that is\ncompatible with the \"readline-ext\" gem and implemented in pure Ruby.\n".freeze
  s.email = ["aycabta@gmail.com".freeze]
  s.homepage = "https://github.com/ruby/readline".freeze
  s.licenses = ["Ruby".freeze]
  s.post_install_message = "+---------------------------------------------------------------------------+\n| This is just a loader for \"readline\". If Ruby has the \"readline-ext\" gem  |\n| that is a native extension, this gem will load it. If Ruby does not have  |\n| the \"readline-ext\" gem this gem will load \"reline\", a library that is     |\n| compatible with the \"readline-ext\" gem and implemented in pure Ruby.      |\n|                                                                           |\n| If you intend to use GNU Readline by `require 'readline'`, please install |\n| the \"readline-ext\" gem.                                                   |\n+---------------------------------------------------------------------------+\n".freeze
  s.rubygems_version = "3.4.20".freeze
  s.summary = "Loader for \"readline\".".freeze

  s.installed_by_version = "3.4.20" if s.respond_to? :installed_by_version

  s.specification_version = 4

  s.add_runtime_dependency(%q<reline>.freeze, [">= 0"])
end
