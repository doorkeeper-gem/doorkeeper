# [Coveralls Reborn](https://coveralls.io) for Ruby

[![Gem Version](https://badge.fury.io/rb/coveralls_reborn.svg)](https://badge.fury.io/rb/coveralls_reborn)
[![Build Status](https://github.com/tagliala/coveralls-ruby-reborn/actions/workflows/ruby.yml/badge.svg)](https://github.com/tagliala/coveralls-ruby-reborn/actions/workflows/ruby.yml)
[![Rubocop](https://github.com/tagliala/coveralls-ruby-reborn/actions/workflows/rubocop.yml/badge.svg)](https://github.com/tagliala/coveralls-ruby-reborn/actions/workflows/rubocop.yml)
[![Coverage Status](https://coveralls.io/repos/github/tagliala/coveralls-ruby-reborn/badge.svg?branch=main)](https://coveralls.io/github/tagliala/coveralls-ruby-reborn?branch=main)

[Coveralls.io](https://coveralls.io) was designed with Ruby projects in mind, so we've made it as
easy as possible to get started using [Coveralls](https://coveralls.io) with Ruby and Rails project.

An up-to-date fork of [lemurheavy/coveralls-ruby](https://github.com/lemurheavy/coveralls-ruby)

### PREREQUISITES

- Using a supported repo host ([GitHub](https://github.com/) | [Gitlab](https://gitlab.com/) |
  [Bitbucket](https://bitbucket.org/))
- Building on a supported CI service (see
  [supported CI services](https://docs.coveralls.io/ci-services) here)
- Any Ruby project or test framework supported by
  [SimpleCov](https://github.com/colszowka/simplecov) is supported by the
  [coveralls-ruby-reborn](https://github.com/tagliala/coveralls-ruby-reborn) gem. This includes
  all your favorites, like [RSpec](https://rspec.info/), Cucumber, and Test::Unit.

### INSTALLING THE GEM

You shouldn't need more than a quick change to get your project on Coveralls. Just include
[coveralls-ruby-reborn](https://github.com/tagliala/coveralls-ruby-reborn) in your project's
Gemfile like so:

```ruby
# ./Gemfile

gem 'coveralls_reborn', require: false
```

### CONFIGURATION

[coveralls-ruby-reborn](https://github.com/tagliala/coveralls-ruby-reborn) uses an optional
`.coveralls.yml` file at the root level of your repository to configure options.

The option `repo_token` (found on your repository's page on Coveralls) is used to specify which
project on Coveralls your project maps to.

Another important configuration option is `service_name`, which indicates your CI service and allows
you to specify where Coveralls should look to find additional information about your builds. This
can be any string, but using the appropriate string for your service may allow Coveralls to perform
service-specific actions like fetching branch data and commenting on pull requests.

**Example: A .coveralls.yml file configured for Travis Pro:**

```yml
service_name: travis-pro
```

**Example: Passing `repo_token` from the command line:**

```console
COVERALLS_REPO_TOKEN=asdfasdf bundle exec rspec spec
```

### TEST SUITE SETUP

After configuration, the next step is to add
[coveralls-ruby-reborn](https://github.com/tagliala/coveralls-ruby-reborn) to your test suite.

For a Ruby app:

```ruby
# ./spec/spec_helper.rb
# ./test/test_helper.rb
# ..etc..

require 'coveralls'
Coveralls.wear!
```

For a Rails app:

```ruby
require 'coveralls'
Coveralls.wear!('rails')
```

**Note:** The `Coveralls.wear!` must occur before any of your application code is required, so it
should be at the **very top** of your `spec_helper.rb`, `test_helper.rb`, or `env.rb`, etc.

And holy moly, you're done!

Next time your project is built on CI, [SimpleCov](https://github.com/colszowka/simplecov) will dial
up [Coveralls.io](https://coveralls.io) and send the hot details on your code coverage.

### SIMPLECOV CUSTOMIZATION

*"But wait!"* you're saying, *"I already use SimpleCov, and I have some custom settings! Are you
really just overriding everything I've already set up?"*

Good news, just use this gem's [SimpleCov](https://github.com/colszowka/simplecov) formatter
directly:

```ruby
require 'simplecov'
require 'coveralls'

SimpleCov.formatter = Coveralls::SimpleCov::Formatter
SimpleCov.start do
  add_filter 'app/secrets'
end
```

Or alongside another formatter, like so:

```ruby
require 'simplecov'
require 'coveralls'

SimpleCov.formatters = [
  SimpleCov::Formatter::HTMLFormatter,
  Coveralls::SimpleCov::Formatter
]
SimpleCov.start
```

### MERGING MULTIPLE TEST SUITES

If you're using more than one test suite and want the coverage results to be merged, use
`Coveralls.wear_merged!` instead of `Coveralls.wear!`.

Or, if you're using Coveralls alongside another [SimpleCov](https://github.com/colszowka/simplecov)
formatter, simply omit the Coveralls formatter, then add the rake task `coveralls:push` to your
`Rakefile` as a dependency to your testing task, like so:

```ruby
require 'coveralls/rake/task'
Coveralls::RakeTask.new
task :test_with_coveralls => [:spec, :features, 'coveralls:push']
```

This will prevent Coveralls from sending coverage data after each individual suite, instead waiting
until [SimpleCov](https://github.com/colszowka/simplecov) has merged the results, which are then
posted to [Coveralls.io](https://coveralls.io).

Unless you've added `coveralls:push` to your default rake task, your build command will need to be
updated on your CI to reflect this, for example:

```console
bundle exec rake :test_with_coveralls
```

*Read more about [SimpleCov's result merging](https://github.com/colszowka/simplecov#merging-results).*

### MANUAL BUILDS VIA CLI

[coveralls-ruby-reborn](https://github.com/tagliala/coveralls-ruby-reborn) also allows you to
upload coverage data manually by running your test suite locally.

To do this with [RSpec](https://rspec.info/), just type `bundle exec coveralls push` in your project
directory.

This will run [RSpec](https://rspec.info/) and upload the coverage data to
[Coveralls.io](https://coveralls.io) as a one-off build, passing along any configuration options
specified in `.coveralls.yml`.


### GitHub Actions

Psst... you don't need this gem on GitHub Actions.

For a Rails application, just add

```rb
gem 'simplecov-lcov', '~> 0.8.0'
```

to your `Gemfile` and

```rb
require 'simplecov'

SimpleCov.start 'rails' do
  if ENV['CI']
    require 'simplecov-lcov'

    SimpleCov::Formatter::LcovFormatter.config do |c|
      c.report_with_single_file = true
      c.single_report_path = 'coverage/lcov.info'
    end

    formatter SimpleCov::Formatter::LcovFormatter
  end

  add_filter %w[version.rb initializer.rb]
end
```

at the top of `spec_helper.rb` / `rails_helper.rb` / `test_helper.rb`.

Then follow instructions at [Coveralls GitHub Action](https://github.com/marketplace/actions/coveralls-github-action)
