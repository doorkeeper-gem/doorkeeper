# -*- encoding: utf-8 -*-
# stub: term-ansicolor 1.11.3 ruby lib

Gem::Specification.new do |s|
  s.name = "term-ansicolor".freeze
  s.version = "1.11.3".freeze

  s.required_rubygems_version = Gem::Requirement.new(">= 0".freeze) if s.respond_to? :required_rubygems_version=
  s.require_paths = ["lib".freeze]
  s.authors = ["Florian Frank".freeze]
  s.date = "1980-01-02"
  s.description = "This library uses ANSI escape sequences to control the attributes of terminal output".freeze
  s.email = "flori@ping.de".freeze
  s.executables = ["term_cdiff".freeze, "term_colortab".freeze, "term_decolor".freeze, "term_display".freeze, "term_mandel".freeze, "term_plasma".freeze, "term_snow".freeze]
  s.extra_rdoc_files = ["README.md".freeze, "lib/term/ansicolor.rb".freeze, "lib/term/ansicolor/attribute.rb".freeze, "lib/term/ansicolor/attribute/color256.rb".freeze, "lib/term/ansicolor/attribute/color8.rb".freeze, "lib/term/ansicolor/attribute/intense_color8.rb".freeze, "lib/term/ansicolor/attribute/text.rb".freeze, "lib/term/ansicolor/attribute/underline.rb".freeze, "lib/term/ansicolor/hsl_triple.rb".freeze, "lib/term/ansicolor/hyperlink.rb".freeze, "lib/term/ansicolor/movement.rb".freeze, "lib/term/ansicolor/ppm_reader.rb".freeze, "lib/term/ansicolor/rgb_color_metrics.rb".freeze, "lib/term/ansicolor/rgb_triple.rb".freeze, "lib/term/ansicolor/version.rb".freeze]
  s.files = ["CHANGES.md".freeze, "Gemfile".freeze, "LICENSE".freeze, "README.md".freeze, "Rakefile".freeze, "bin/term_cdiff".freeze, "bin/term_colortab".freeze, "bin/term_decolor".freeze, "bin/term_display".freeze, "bin/term_mandel".freeze, "bin/term_plasma".freeze, "bin/term_snow".freeze, "examples/example.rb".freeze, "examples/lambda-red-plain.ppm".freeze, "examples/lambda-red.png".freeze, "examples/lambda-red.ppm".freeze, "lib/term/ansicolor.rb".freeze, "lib/term/ansicolor/.keep".freeze, "lib/term/ansicolor/attribute.rb".freeze, "lib/term/ansicolor/attribute/color256.rb".freeze, "lib/term/ansicolor/attribute/color8.rb".freeze, "lib/term/ansicolor/attribute/intense_color8.rb".freeze, "lib/term/ansicolor/attribute/text.rb".freeze, "lib/term/ansicolor/attribute/underline.rb".freeze, "lib/term/ansicolor/hsl_triple.rb".freeze, "lib/term/ansicolor/hyperlink.rb".freeze, "lib/term/ansicolor/movement.rb".freeze, "lib/term/ansicolor/ppm_reader.rb".freeze, "lib/term/ansicolor/rgb_color_metrics.rb".freeze, "lib/term/ansicolor/rgb_triple.rb".freeze, "lib/term/ansicolor/version.rb".freeze, "term-ansicolor.gemspec".freeze, "tests/ansicolor_test.rb".freeze, "tests/attribute_test.rb".freeze, "tests/hsl_triple_test.rb".freeze, "tests/hyperlink_test.rb".freeze, "tests/ppm_reader_test.rb".freeze, "tests/rgb_color_metrics_test.rb".freeze, "tests/rgb_triple_test.rb".freeze, "tests/test_helper.rb".freeze]
  s.homepage = "https://github.com/flori/term-ansicolor".freeze
  s.licenses = ["Apache-2.0".freeze]
  s.rdoc_options = ["--title".freeze, "Term-ansicolor - Ruby library that colors strings using ANSI escape sequences".freeze, "--main".freeze, "README.md".freeze]
  s.rubygems_version = "3.6.9".freeze
  s.summary = "Ruby library that colors strings using ANSI escape sequences".freeze
  s.test_files = ["tests/ansicolor_test.rb".freeze, "tests/attribute_test.rb".freeze, "tests/hsl_triple_test.rb".freeze, "tests/hyperlink_test.rb".freeze, "tests/ppm_reader_test.rb".freeze, "tests/rgb_color_metrics_test.rb".freeze, "tests/rgb_triple_test.rb".freeze, "tests/test_helper.rb".freeze]

  s.specification_version = 4

  s.add_development_dependency(%q<gem_hadar>.freeze, ["~> 2.4".freeze])
  s.add_development_dependency(%q<simplecov>.freeze, [">= 0".freeze])
  s.add_development_dependency(%q<test-unit>.freeze, [">= 0".freeze])
  s.add_development_dependency(%q<debug>.freeze, [">= 0".freeze])
  s.add_development_dependency(%q<all_images>.freeze, ["~> 0.8".freeze])
  s.add_runtime_dependency(%q<tins>.freeze, ["~> 1".freeze])
end
