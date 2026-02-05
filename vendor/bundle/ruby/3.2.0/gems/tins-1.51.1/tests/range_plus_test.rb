require 'test_helper'
require 'tins/xt'

module Tins
  class RangePlustTest < Test::Unit::TestCase

    def test_range_plus
      assert_equal [], (0...0) + (0...0)
      assert_equal [ 0 ], (0..0) + (0...0)
      assert_equal [ 0, 0 ], (0..0) + (0..0)
      assert_equal((1..5).to_a, (1...3) + (3..5))
    end
  end
end
