require 'test_helper'
require 'tins/xt'

module Tins
  class PartialApplicationTest < Test::Unit::TestCase

    def mul(x, y) x * y end

    define_method(:dup) { |y| method(:mul).partial(2)[y] }

    define_method(:trip) { |y| method(:mul).partial(3)[y] }


    def test_proc
      mul   = lambda { |x, y| x * y }
      assert_equal 2, mul.arity
      klon  = mul.partial
      assert_equal 2, klon.arity
      dup   = mul.partial(2)
      assert_equal 1, dup.arity
      trip  = mul.partial(3)
      assert_equal 1, trip.arity
      assert_equal [ 6, 9, 12 ], [ dup[3], trip[3], mul[4, 3] ]
      assert_equal [ 6, 9, 12 ], [ dup[3], trip[3], klon[4, 3] ]
      assert_raise(ArgumentError) do
        mul.partial(1, 2, 3)
      end
    end

    def test_method
      assert_equal [ 6, 9, 12 ], [ dup(3), trip(3), mul(4, 3) ]
    end
  end
end
