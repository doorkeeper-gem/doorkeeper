# vim: set filetype=ruby et sw=2 ts=2:

require 'gem_hadar'

GemHadar do
  name        'mize'
  author      'Florian Frank'
  email       'flori@ping.de'
  homepage    "https://github.com/flori/#{name}"
  summary     'Library that provides memoziation for methods and functions'
  description "#{summary} for Ruby."
  readme      'README.md'
  licenses << 'MIT'

  test_dir    'spec'
  yard_dir    'doc'

  ignore      '.*.sw[pon]', 'pkg', 'Gemfile.lock', 'coverage', '.rvmrc',
    '.AppleDouble', 'tags', '.byebug_history', '.yard*', 'yard', 'doc',
    'errors.lst'


  development_dependency 'rake'
  development_dependency 'simplecov'
  development_dependency 'rspec'
  development_dependency 'yard'
  development_dependency 'all_images'
  development_dependency 'debug'

  required_ruby_version '>= 2'
end

task :default => :spec
