require 'test_helper'

module Tins
  class NullTest < Test::Unit::TestCase
    require 'tins/xt/null'

    def test_null
      assert_equal NULL, NULL.foo
      assert_equal NULL, NULL.foo.bar
      assert_equal 'NULL', NULL.inspect
      assert_equal '', NULL.to_s
      assert_equal 0, NULL.to_i
      assert_equal 0.0, NULL.to_f
      assert_equal [], NULL.to_a
      assert_equal 1, null(1)
      assert_equal 1, Null(1)
      assert_equal NULL, null(nil)
      assert_equal NULL, Null(nil)
      assert_equal NULL, NULL::NULL
      assert NULL.nil?
      assert NULL.blank?
      assert_equal nil, NULL.as_json
      assert_equal 'null', NULL.to_json
    end

    def test_null_plus
      assert_equal 1, null_plus(value: 1)
      assert_equal 1, NullPlus(value: 1)
      assert_kind_of Tins::NullPlus, null_plus(value: nil)
      assert_kind_of Tins::NullPlus, NullPlus(value: nil)
      assert_kind_of Tins::NullPlus, null_plus
      assert_kind_of Tins::NullPlus, NullPlus()
      assert_kind_of Tins::NullPlus, null_plus.foo
      assert_kind_of Tins::NullPlus, null_plus.foo.bar
      assert_kind_of Tins::NullPlus, NullPlus().foo
      assert_kind_of Tins::NullPlus, NullPlus().foo.bar
      assert null_plus.nil?
      assert null_plus().blank?
      assert_equal nil, null_plus().as_json
      assert_equal 'null', null_plus.to_json
      assert NullPlus().nil?
      assert NullPlus().blank?
      assert_equal nil, NullPlus().as_json
      assert_equal 'null', NullPlus().to_json
    end

    def foo
      1 / 0
    rescue => e
      null_plus(error: e)
    end

    def test_null_plus_caller_and_misc
      assert_match(/foo/, foo.caller.first)
      if foo.respond_to?(:caller_locations)
        assert_kind_of Thread::Backtrace::Location, foo.caller_locations.first
        assert_match(/foo/, foo.caller_locations.first.to_s)
      end
      assert_match(/foo/, foo.caller.first)
      assert_kind_of ZeroDivisionError, foo.error
    end
  end
end
