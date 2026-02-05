require 'test_helper'

module Tins
  class RotateTest < Test::Unit::TestCase
    def test_rotate_bang
      a = [ 1, 2, 3 ]
      assert_same a, a.rotate!
    end

    def test_rotate_bang_0
      a = [ 1, 2, 3 ]
      assert_equal [ 1, 2, 3 ], a.rotate!(0)
    end

    def test_rotate_bang_1
      a = [ 1, 2, 3 ]
      assert_equal [ 2, 3, 1 ], a.rotate!(1)
    end

    def test_rotate_bang_2
      a = [ 1, 2, 3 ]
      assert_equal [ 3, 1, 2 ], a.rotate!(2)
    end

    def test_rotate_bang_minus_1
      a = [ 1, 2, 3 ]
      assert_equal [ 3, 1, 2 ], a.rotate!(-1)
    end

    def test_rotate_bang_minus_2
      a = [ 1, 2, 3 ]
      assert_equal [ 2, 3, 1 ], a.rotate!(-2)
    end

    def test_rotate
      a = [ 1, 2, 3 ]
      assert_not_same a, a.rotate
    end

    def test_rotate_0
      a = [ 1, 2, 3 ]
      assert_equal [ 1, 2, 3 ], a.rotate(0)
    end

    def test_rotate_1
      a = [ 1, 2, 3 ]
      assert_equal [ 2, 3, 1 ], a.rotate(1)
    end

    def test_rotate_2
      a = [ 1, 2, 3 ]
      assert_equal [ 3, 1, 2 ], a.rotate(2)
    end

    def test_rotate_minus_1
      a = [ 1, 2, 3 ]
      assert_equal [ 3, 1, 2 ], a.rotate(-1)
    end

    def test_rotate_minus_2
      a = [ 1, 2, 3 ]
      assert_equal [ 2, 3, 1 ], a.rotate(-2)
    end
  end
end
