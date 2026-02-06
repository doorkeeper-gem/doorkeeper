# vim: set filetype=ruby et sw=2 ts=2:

require 'gem_hadar'

GemHadar do
  name              'tins'
  author            'Florian Frank'
  email             'flori@ping.de'
  homepage          "https://github.com/flori/#{name}"
  summary           'Useful stuff.'
  description       'All the stuff that isn\'t good/big enough for a real library.'
  test_dir          'tests'
  test_files.concat Dir["#{test_dir}/*_test.rb"]
  doc_code_files    files.grep(%r(\Alib/))
  ignore            '.*.sw[pon]', 'pkg', 'Gemfile.lock', '.rvmrc', 'coverage',
    '.rbx', '.AppleDouble', '.DS_Store', 'tags', 'cscope.out', '.bundle',
    '.yardoc', 'doc', 'TODO.md'
  package_ignore    '.all_images.yml', '.tool-versions', '.gitignore',
    'VERSION', '.utilsrc', '.github', '.contexts'

  readme            'README.md'
  licenses <<       'MIT'
  clean <<          'coverage'

  changelog do
    filename 'CHANGES.md'
  end

  github_workflows(
    'static.yml' => {}
  )

  required_ruby_version  '>= 3.1'

  dependency 'sync'
  dependency 'bigdecimal'
  dependency 'readline'
  dependency 'mize',     '~> 0.6'
  development_dependency 'all_images'
  development_dependency 'debug'
  development_dependency 'simplecov'
  development_dependency 'term-ansicolor'
  development_dependency 'test-unit', '~> 3.7'
end
