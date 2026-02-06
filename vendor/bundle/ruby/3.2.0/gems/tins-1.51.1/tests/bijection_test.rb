require 'test_helper'

module Tins
  class BijectionTest < Test::Unit::TestCase
    def test_bijection
      assert_equal [ [ 1, 2 ], [ 3, 4 ] ], Tins::Bijection[ 1, 2, 3, 4 ].to_a.sort
      assert_raise(ArgumentError) do
        Tins::Bijection[1,2,3]
      end
      assert_raise(ArgumentError) do
        Tins::Bijection[1,2,3,2]
      end
      assert_raise(ArgumentError) do
        Tins::Bijection[1,2,1,3]
      end
    end
  end
end
