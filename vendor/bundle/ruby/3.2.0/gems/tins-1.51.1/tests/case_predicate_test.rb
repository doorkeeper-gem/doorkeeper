require 'test_helper'
require 'tins/xt/case_predicate'

module Tins
  class CasePredicateTest < Test::Unit::TestCase
    def test_case_predicate_failure
      assert_nil 4.case?(1, 2..3, 5...7)
    end

    def test_case_predicate_failure_is_a
      s = 'foo'
      assert_nil s.case?(Array, Hash)
      s = Class.new(String).new
      assert_nil s.case?(Array, Hash)
    end

    def test_case_predicate_success
      assert_equal 2..3, 3.case?(1, 2..3, 5...7)
    end

    def test_case_predicate_success_is_a
      s = 'foo'
      assert_equal String, s.case?(Array, Hash, String)
      s = Class.new(String).new
      assert_equal String, s.case?(Array, Hash, String)
    end
  end
end

