require 'test_helper'
require 'tins/xt'

module Tins
  class RespondingTest < Test::Unit::TestCase
    class A
      def foo() end

      def bar() end
    end

    def test_responding
      assert_equal true, responding?(:foo) === A.new
      assert_equal false, responding?(:jflafjdklfjaslkdfj) === A.new
      assert_equal false, responding?(:jflafjdklfjaslkdfj, :foo) === A.new
      assert_equal true, responding?(:foo, :bar) === A.new
    end

    def test_responding_to_s
      assert_equal 'Responding to foo', responding?(:foo).to_s
      assert_equal 'Responding to foo', responding?(:foo).inspect
    end
  end
end
