require 'test_helper'
require 'tins/xt'

module Tins
  class StringCamelizeTest < Test::Unit::TestCase
    def test_camelize
      assert_equal 'FooBar', 'foo_bar'.camelize
      assert_equal 'FooBar', 'foo_bar'.camelize(:upper)
      assert_equal 'FooBar', 'foo_bar'.camelize(true)
      assert_equal 'fooBar', 'foo_bar'.camelize(:lower)
      assert_equal 'fooBar', 'foo_bar'.camelize(false)
      assert_equal 'FooBar', 'foo_bar'.camelcase
      assert_equal 'Foo::Bar', 'foo/bar'.camelize
      assert_equal 'Foo::Bar', 'foo/bar'.camelize(:upper)
      assert_equal 'Foo::Bar', 'foo/bar'.camelize(true)
      assert_equal 'foo::Bar', 'foo/bar'.camelize(:lower)
      assert_equal 'foo::Bar', 'foo/bar'.camelize(false)
      assert_equal 'Foo::Bar', 'foo/bar'.camelcase
    end
  end
end
