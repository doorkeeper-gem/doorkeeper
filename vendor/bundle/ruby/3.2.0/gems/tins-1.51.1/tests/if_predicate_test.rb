require 'test_helper'
require 'tins/xt'

module Tins
  class IfPredicateTest < Test::Unit::TestCase
    def test_if_predicate
      assert_equal :foo, true.if? && :foo
      assert_nil false.if? && :foo
      assert_nil nil.if? && :foo
    end
  end
end
