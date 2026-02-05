require 'test_helper'

module Tins
  class MinimizeTest < Test::Unit::TestCase
    class ::Array
      include Tins::Minimize
    end

    def test_minimize
      assert_equal [], [].minimize
      assert_equal [ 1..1 ], [ 1 ].minimize
      assert_equal [ 1..2 ], [ 1, 2 ].minimize
      assert_equal [ 1..1, 7..7 ], [ 1, 7 ].minimize
      assert_equal [ 1..3, 7..7, 11..14 ],
        [ 1, 2, 3, 7, 11, 12, 13, 14 ].minimize
      assert_equal [ 'A'..'C', 'G'..'G', 'K'..'M' ],
        [ 'A', 'B', 'C', 'G', 'K', 'L', 'M' ].minimize
    end

    def test_minimize!
      assert_equal [], [].minimize!
      assert_equal [ 1..1 ], [ 1 ].minimize!
      assert_equal [ 1..2 ], [ 1, 2 ].minimize!
      assert_equal [ 1..1, 7..7 ], [ 1, 7 ].minimize!
      assert_equal [ 1..3, 7..7, 11..14 ],
        [ 1, 2, 3, 7, 11, 12, 13, 14 ].minimize!
      assert_equal [ 'A'..'C', 'G'..'G', 'K'..'M' ],
        [ 'A', 'B', 'C', 'G', 'K', 'L', 'M' ].minimize!
    end

    def test_unminimize
      assert_equal [], [].unminimize
      assert_equal [ 1 ], [ 1..1 ].unminimize
      assert_equal [ 1, 2 ], [ 1..2 ].unminimize
      assert_equal [ 1, 7 ], [ 1..1, 7..7 ].unminimize
      assert_equal [ 1, 2, 3, 7, 11, 12, 13, 14 ],
        [ 1..3, 7..7, 11..14 ].unminimize
      assert_equal [ 'A', 'B', 'C', 'G', 'K', 'L', 'M' ],
        [ 'A'..'C', 'G'..'G', 'K'..'M' ].unminimize
    end

    def test_unminimize!
      assert_equal [], [].unminimize!
      assert_equal [ 1 ], [ 1..1 ].unminimize!
      assert_equal [ 1, 2 ], [ 1..2 ].unminimize!
      assert_equal [ 1, 7 ], [ 1..1, 7..7 ].unminimize!
      assert_equal [ 1, 2, 3, 7, 11, 12, 13, 14 ],
        [ 1..3, 7..7, 11..14 ].unminimize!
      assert_equal [ 'A', 'B', 'C', 'G', 'K', 'L', 'M' ],
        [ 'A'..'C', 'G'..'G', 'K'..'M' ].unminimize!
    end
  end
end
