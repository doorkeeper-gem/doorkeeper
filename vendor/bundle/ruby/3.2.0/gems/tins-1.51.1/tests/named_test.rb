require 'test_helper'
require 'tins/xt'

module Tins
  class NamedTest < Test::Unit::TestCase

    def test_named_simple
      a = [ 1, 2, 3 ]
      a.named(:plus1, :map) { |x| x + 1 }
      assert_equal [ 2, 3, 4 ], a.plus1
      Array.named(:odd, :select) { |x| x % 2 == 1 }
      assert_equal [ 3 ], a.plus1.odd
    end

    def foo(x, y, &block)
      block.call x * y
    end

    def test_more_complex
      Object.named(:foo_with_block, :foo) do |z|
        z ** 2
      end
      assert_equal foo(2, 3) { |z| z ** 2 }, foo_with_block(2, 3)
      Object.named(:foo_23, :foo, 2, 3)
      assert_equal foo(2, 3) { |z| z ** 2 }, foo_23 { |z| z ** 2 }
      Object.named(:foo_2, :foo, 2)
      assert_equal foo(2, 3) { |z| z ** 2 }, foo_2(3) { |z| z ** 2 }
    end
  end
end
