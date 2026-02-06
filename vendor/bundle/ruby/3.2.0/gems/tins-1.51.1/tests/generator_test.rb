require 'test_helper'

module Tins
  class GeneratorTest < Test::Unit::TestCase
    def setup
      @numeric = [ 1, 2, 3 ]
      @string  = %w[a b c]
      @chars   = 'abc'
    end

    def test_generator
      g = Tins::Generator[@numeric, @string]
      assert_equal 2, g.size
      g.add_dimension(@chars, :each_byte)
      assert_equal 3, g.size
      assert_equal\
        [[1, "a", 97],
        [1, "a", 98],
        [1, "a", 99],
        [1, "b", 97],
        [1, "b", 98],
        [1, "b", 99],
        [1, "c", 97],
        [1, "c", 98],
        [1, "c", 99],
        [2, "a", 97],
        [2, "a", 98],
        [2, "a", 99],
        [2, "b", 97],
        [2, "b", 98],
        [2, "b", 99],
        [2, "c", 97],
        [2, "c", 98],
        [2, "c", 99],
        [3, "a", 97],
        [3, "a", 98],
        [3, "a", 99],
        [3, "b", 97],
        [3, "b", 98],
        [3, "b", 99],
        [3, "c", 97],
        [3, "c", 98],
        [3, "c", 99]], g.to_a
    end
  end
end
