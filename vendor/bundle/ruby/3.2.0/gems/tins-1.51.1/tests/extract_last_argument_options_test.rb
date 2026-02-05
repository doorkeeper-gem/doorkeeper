require 'test_helper'

module Tins
  class ExtractLastArgumentOptionsTest < Test::Unit::TestCase
    require 'tins/xt/extract_last_argument_options'

    def test_empty_argument_array
      arguments = []
      result = arguments.extract_last_argument_options
      assert_equal [ [], {} ], result
      assert_not_same arguments, result.first
    end

    def test_argument_array_without_options
      arguments = [ 1, 2, 3 ]
      result = arguments.extract_last_argument_options
      assert_equal [ [ 1, 2, 3 ], {} ], result
      assert_not_same arguments, result.first
    end

    def test_argument_array_witt_options
      arguments = [ 1, 2, 3, { foo: :bar } ]
      result = arguments.extract_last_argument_options
      assert_equal [ [ 1, 2, 3 ], { foo: :bar } ], result
      assert_not_same arguments, result.first
      assert_not_same arguments.last, result.last
    end
  end
end
