# Generator Spec [![Build Status](https://travis-ci.org/stevehodgkiss/generator_spec.svg?branch=master)](https://travis-ci.org/stevehodgkiss/generator_spec)

Test Rails generators with RSpec using the standard Rails::Generators::TestCase assertion methods.

# Usage

Gemfile:

```ruby
group :test do
  gem "generator_spec"
end
```

Spec (files in `spec/lib/generators` are recognized as generator type example group):

```ruby
# spec/lib/generators/test/test_generator_spec.rb

require "generator_spec"

describe TestGenerator, type: :generator do
  destination File.expand_path("../../tmp", __FILE__)
  arguments %w(something)

  before(:all) do
    prepare_destination
    run_generator
  end

  it "creates a test initializer" do
    assert_file "config/initializers/test.rb", "# Initializer"
  end
end
```

An RSpec file matching DSL is also provided, taken with permission from [beard](https://github.com/carlhuda/beard/blob/master/spec/support/matcher.rb) by [carlhuda](https://github.com/carlhuda).

```ruby
describe TestGenerator, "using custom matcher", type: :generator do
  destination File.expand_path("../../tmp", __FILE__)

  before do
    prepare_destination
    run_generator
  end

  specify do
    expect(destination_root).to have_structure {
      no_file "test.rb"
      directory "config" do
        directory "initializers" do
          file "test.rb" do
            contains "# Initializer"
            does_not_contain "Something else"
          end
        end
      end
      directory "db" do
        directory "migrate" do
          file "123_create_tests.rb"
          migration "create_tests" do
            contains "class TestMigration"
            does_not_contain "Something else"
          end
        end
      end
    }
  end
end
```
