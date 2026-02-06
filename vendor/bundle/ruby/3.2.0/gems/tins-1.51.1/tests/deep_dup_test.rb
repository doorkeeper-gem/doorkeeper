require 'test_helper'
require 'tins/xt'

module Tins
  class DeepDupTest < Test::Unit::TestCase
    def test_deep_dup
      a = [1,2,3]
      assert_equal    a, a.deep_dup
      assert_not_same a, a.deep_dup
    end

    def test_deep_dup_proc
      f = lambda { |x| 2 * x }
      g = f.deep_dup
      assert_equal f[3], g[3]
      assert_equal f, g
      assert_same  f, g
    end
  end
end
