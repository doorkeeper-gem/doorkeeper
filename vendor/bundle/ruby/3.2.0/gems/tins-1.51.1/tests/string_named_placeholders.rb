require 'test_helper'
require 'tins/xt'

module Tins
  class StringNamedPlaceholdersTest < Test::Unit::TestCase

    def test_named_placeholders
      # Basic functionality
      assert_equal [:name], "Hello %{name}!".named_placeholders
      assert_equal [:name, :age], "Hello %{name}, you are %{age} years old".named_placeholders
      assert_equal [:foo, :bar], "%{foo} and %{bar}".named_placeholders

      # Duplicate handling
      assert_equal [:name], "%{name} and %{name}".named_placeholders

      # Mixed content
      assert_equal [:title, :content], "Title: %{title}\nContent: %{content}".named_placeholders

      # No placeholders
      assert_equal [], "Hello World".named_placeholders
    end

    def test_named_placeholders_assign
      # Basic assignment with static default
      result = "%{name} is %{age}".named_placeholders_assign({name: 'Alice'}, default: '[n/a]')
      assert_equal({name: 'Alice', age: '[n/a]'}, result)

      # All values provided
      result = "%{name} is %{age}".named_placeholders_assign({name: 'Alice', age: 30}, default: '[n/a]')
      assert_equal({name: 'Alice', age: 30}, result)

      # No values provided
      result = "%{name} is %{age}".named_placeholders_assign({}, default: '[n/a]')
      assert_equal({name: '[n/a]', age: '[n/a]'}, result)

      # Dynamic defaults via Proc
      result = "%{name} is %{age}".named_placeholders_assign({name: 'Alice'}, default: ->(key) { "[missing_#{key}]" })
      assert_equal({name: 'Alice', age: '[missing_age]'}, result)

      # Key conversion
      result = "%{name} is %{age}".named_placeholders_assign({'name' => 'Alice'}, default: '[n/a]')
      assert_equal({name: 'Alice', age: '[n/a]'}, result)

      # Empty string values (should work)
      result = "%{name}".named_placeholders_assign({name: ''}, default: '[n/a]')
      assert_equal({name: ''}, result)
    end

    def test_integration
      # Complete template substitution example
      template = "Hello %{name}, you are %{age} years old and live in %{city}"
      values = template.named_placeholders_assign({name: 'Bob', age: 25}, default: '[n/a]')
      result = template % values
      assert_equal "Hello Bob, you are 25 years old and live in [n/a]", result

      # Raise custom expcetion if missing
      assert_raise(ArgumentError, "Required placeholder age not provided") do
        template.named_placeholders_assign(
          {name: 'Alice'},
          default: ->(key) { raise ArgumentError, "Required placeholder #{key} not provided" })
      end

      # All values provided
      values = template.named_placeholders_assign({name: 'Charlie', age: 30, city: 'NYC'}, default: '[n/a]')
      result = template % values
      assert_equal "Hello Charlie, you are 30 years old and live in NYC", result
    end

    def test_named_placeholders_interpolate
      # Basic interpolation with defaults
      result = "Hello %{name}, you are %{age} years old".named_placeholders_interpolate({name: 'Alice'}, default: '[n/a]')
      assert_equal "Hello Alice, you are [n/a] years old", result

      # All values provided - should work without defaults
      result = "Hello %{name}, you are %{age} years old".named_placeholders_interpolate({name: 'Bob', age: 30})
      assert_equal "Hello Bob, you are 30 years old", result

      # Dynamic defaults via Proc
      result = "Hello %{name}, you are %{age} years old".named_placeholders_interpolate(
        {name: 'Charlie'},
        default: ->(key) { "[missing_#{key}]" }
      )
      assert_equal "Hello Charlie, you are [missing_age] years old", result

      # Key conversion from string keys
      result = "Hello %{name}, you are %{age} years old".named_placeholders_interpolate(
        {'name' => 'David'},
        default: '[n/a]'
      )
      assert_equal "Hello David, you are [n/a] years old", result

      # No placeholders in template
      result = "Hello World".named_placeholders_interpolate({some_key: 'value'})
      assert_equal "Hello World", result

      # Empty string values
      result = "Hello %{name}".named_placeholders_interpolate({name: ''}, default: '[n/a]')
      assert_equal "Hello ", result

      # Raise custom expcetion if missing
      template = "Hello %{name}, you are %{age} years old and live in %{city}"
      assert_raise(ArgumentError, "Required placeholder age not provided") do
        template.named_placeholders_interpolate(
          {name: 'Alice'},
          default: ->(key) { raise ArgumentError, "Required placeholder #{key} not provided" })
      end
    end
  end
end
