require 'test_helper'
require 'tins/xt'

module Tins
  class ProcComposeTest < Test::Unit::TestCase

    def test_proc_compose_simple
      f = lambda { |x| 2 * x }
      g = lambda { |x| x + 1 }
      assert_equal 6, (f * g).call(2)
    end

    def test_proc_compose_more_complex
      f = lambda { |x, y| 2 * x + y * 3 }
      g = lambda { |x| x + 1 }
      assert_raise(ArgumentError) { (f * g).call(2, 3) }
      d = lambda { |x| [ x, x ] }
      assert_equal 15, (f * d * g).call(2)
    end
  end
end
