Appraisal
=========

Find out what your Ruby gems are worth.

Synopsis
--------

Appraisal integrates with bundler and rake to test your library against
different versions of dependencies in repeatable scenarios called "appraisals."
Appraisal is designed to make it easy to check for regressions in your library
without interfering with day-to-day development using Bundler.

Installation
------------

In your package's `.gemspec`:

    s.add_development_dependency "appraisal"

Note that gems must be bundled in the global namespace. Bundling gems to a
local location or vendoring plugins is not supported. If you do not want to
pollute the global namespace, one alternative is
[RVM's Gemsets](http://rvm.io/gemsets).

Setup
-----

Setting up appraisal requires an `Appraisals` file (similar to a `Gemfile`) in
your project root, named "Appraisals" (note the case), and some slight changes
to your project's `Rakefile`.

An `Appraisals` file consists of several appraisal definitions. An appraisal
definition is simply a list of gem dependencies. For example, to test with a
few versions of Rails:

    appraise "rails-3" do
      gem "rails", "3.2.14"
    end

    appraise "rails-4" do
      gem "rails", "4.0.0"
    end

The dependencies in your `Appraisals` file are combined with dependencies in
your `Gemfile`, so you don't need to repeat anything that's the same for each
appraisal. If something is specified in both the Gemfile and an appraisal, the
version from the appraisal takes precedence.

Usage
-----

Once you've configured the appraisals you want to use, you need to install the
dependencies for each appraisal:

    $ bundle exec appraisal install

This will resolve, install, and lock the dependencies for that appraisal using
bundler. Once you have your dependencies set up, you can run any command in a
single appraisal:

    $ bundle exec appraisal rails-3 rake test

This will run `rake test` using the dependencies configured for Rails 3. You can
also run each appraisal in turn:

    $ bundle exec appraisal rake test

If you want to use only the dependencies from your Gemfile, just run `rake
test` as normal. This allows you to keep running with the latest versions of
your dependencies in quick test runs, but keep running the tests in older
versions to check for regressions.

In the case that you want to run all the appraisals by default when you run
`rake`, you can override your default Rake task by put this into your Rakefile:

    if !ENV["APPRAISAL_INITIALIZED"] && !ENV["TRAVIS"]
      task :default => :appraisal
    end

(Appraisal sets `APPRAISAL_INITIALIZED` environment variable when it runs your
process. We put a check here to ensure that `appraisal rake` command should run
your real default task, which usually is your `test` task.)

Note that this may conflict with your CI setup if you decide to split the test
into multiple processes by Appraisal and you are using `rake` to run tests by
default.

### Commands

```bash
appraisal clean                  # Remove all generated gemfiles and lockfiles from gemfiles folder
appraisal generate               # Generate a gemfile for each appraisal
appraisal help [COMMAND]         # Describe available commands or one specific command
appraisal install                # Resolve and install dependencies for each appraisal
appraisal list                   # List the names of the defined appraisals
appraisal update [LIST_OF_GEMS]  # Remove all generated gemfiles and lockfiles, resolve, and install dependencies again
appraisal version                # Display the version and exit
```

Under the hood
--------------

Running `appraisal install` generates a Gemfile for each appraisal by combining
your root Gemfile with the specific requirements for each appraisal. These are
stored in the `gemfiles` directory, and should be added to version control to
ensure that the same versions are always used.

When you prefix a command with `appraisal`, the command is run with the
appropriate Gemfile for that appraisal, ensuring the correct dependencies
are used.

Removing Gems using Appraisal
-------

It is common while managing multiple Gemfiles for dependencies to become deprecated and no
longer necessary, meaning they need to be removed from the Gemfile for a specific `appraisal`.
To do this, use the `remove_gem` declaration within the necessary `appraise` block in your
`Appraisals` file.

### Example Usage

**Gemfile**
```ruby
gem 'rails', '~> 4.2'

group :test do
  gem 'rspec', '~> 4.0'
  gem 'test_after_commit'
end
```

**Appraisals**
```ruby
appraise 'rails-5' do
  gem 'rails', '~> 5.2'

  group :test do
    remove_gem :test_after_commit
  end
end
```

Using the `Appraisals` file defined above, this is what the resulting `Gemfile` will look like:
```ruby
gem 'rails', '~> 5.2'

group :test do
  gem 'rspec', '~> 4.0'
end
```

Customization
-------------

It is possible to customize the generated Gemfiles by adding a `customize_gemfiles` block to
your `Appraisals` file. The block must contain a hash of key/value pairs. Currently supported
customizations include:
- heading: a string that by default adds "# This file was generated by Appraisal" to the top of each Gemfile, (the string will be commented for you)
- single_quotes: a boolean that controls if strings are single quoted in each Gemfile, defaults to false

### Example Usage

**Appraisals**
```ruby
customize_gemfiles do
  {
    single_quotes: true,
    heading: <<~HEADING
      frozen_string_literal: true

      File has been generated by Appraisal, do NOT modify it directly!
      See the conventions at https://example.com/
    HEADING
  }
end

appraise "rails-3" do
  gem "rails", "3.2.14"
end
```

Using the `Appraisals` file defined above, this is what the resulting `Gemfile` will look like:
```ruby
# frozen_string_literal: true

# File has been generated by Appraisal, do NOT modify it directly!
# See the conventions at https://example.com/

gem 'rails', '3.2.14'
```

Version Control
---------------

When using Appraisal, we recommend you check in the Gemfiles that Appraisal
generates within the gemfiles directory, but exclude the lockfiles there
(`*.gemfile.lock`.) The Gemfiles are useful when running your tests against a
continuous integration server.

Circle CI Integration
---------------------

In Circle CI you can override the default testing behaviour to customize your
testing. Using this feature you can configure appraisal to execute your tests.

In order to this you can put the following configuration in your circle.yml file:

```yml
dependencies:
  post:
    - bundle exec appraisal install
test:
  pre:
    - bundle exec appraisal rake db:create
    - bundle exec appraisal rake db:migrate
  override:
    - bundle exec appraisal rspec
```

Notice that we are running an rspec suite. You can customize your testing
command in the `override` section and use your favourite one.

Credits
-------

![thoughtbot](https://thoughtbot.com/thoughtbot-logo-for-readmes.svg)

Appraisal is maintained and funded by [thoughtbot, inc][thoughtbot]

Thank you to all [the contributors][contributors]

The names and logos for thoughtbot are trademarks of thoughtbot, inc.

[thoughtbot]: http://thoughtbot.com/community
[contributors]: https://github.com/thoughtbot/appraisal/contributors

License
-------

Appraisal is Copyright © 2010-2013 Joe Ferris and thoughtbot, inc. It is free
software, and may be redistributed under the terms specified in the MIT-LICENSE
file.
