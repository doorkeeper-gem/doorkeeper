require 'test_helper'
require 'tins/xt'

module Tins
  class StringUnderscoreTest < Test::Unit::TestCase
    def test_underscore
      assert_equal 'foo_bar', 'FooBar'.underscore
      assert_equal 'foo/bar', 'Foo::Bar'.underscore
    end
  end
end
