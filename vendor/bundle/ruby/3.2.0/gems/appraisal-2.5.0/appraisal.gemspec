# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)
require "appraisal/version"

Gem::Specification.new do |s|
  s.name        = 'appraisal'
  s.version     = Appraisal::VERSION.dup
  s.platform    = Gem::Platform::RUBY
  s.authors     = ['Joe Ferris', 'Prem Sichanugrist']
  s.email       = ['jferris@thoughtbot.com', 'prem@thoughtbot.com']
  s.homepage    = 'http://github.com/thoughtbot/appraisal'
  s.summary     = 'Find out what your Ruby gems are worth'
  s.description = 'Appraisal integrates with bundler and rake to test your library against different versions of dependencies in repeatable scenarios called "appraisals."'
  s.license     = 'MIT'

  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = ["lib"]

  s.required_ruby_version = ">= 2.3.0"

  s.add_runtime_dependency('rake')
  s.add_runtime_dependency('bundler')
  s.add_runtime_dependency('thor', '>= 0.14.0')

  s.add_development_dependency("activesupport", ">= 3.2.21")
  s.add_development_dependency('rspec', '~> 3.0')
end
