require 'test_helper'

module Tins
  class MemoizeTest < Test::Unit::TestCase
    class FooBar
      def foo(*a)
        @@foo ||= 0
        @@foo += 1
      end
      memoize_method :foo

      def footsie(*a)
        @@footsie ||= 0
        @@footsie += 1
      end
      protected :footsie
      memoize_method :footsie

      def bar(*a)
        @@bar ||= 0
        @@bar += 1
      end
      memoize_function :bar

      private

      def baz(*a)
        @@baz ||= 0
        @@baz += 1
      end
      memoize_function :baz
    end

    def test_method_cache
      fb1 = FooBar.new
      fb2 = FooBar.new
      assert_equal true, fb1.__memoize_cache__.empty?
      assert_equal true, fb2.__memoize_cache__.empty?
      assert_equal 1, fb1.foo(1, 2)
      assert_equal 2, fb2.foo(1, 2)
      assert_equal 3, fb1.foo(1, 2, 3)
      assert_equal 4, fb2.foo(1, 2, 3)
      assert_equal 1, fb1.foo(1, 2)
      assert_equal 2, fb2.foo(1, 2)
      fb1.memoize_cache_clear
      fb2.memoize_cache_clear
      assert_equal true, fb1.__memoize_cache__.empty?
      assert_equal true, fb2.__memoize_cache__.empty?
      assert_equal 5, fb1.foo(1, 2)
      assert_equal 6, fb2.foo(1, 2)
      assert_equal 5, fb1.foo(1, 2)
      assert_equal 6, fb2.foo(1, 2)
      assert_equal false, fb1.__memoize_cache__.empty?
      assert_equal false, fb2.__memoize_cache__.empty?
    end

    def test_method_cache_protected
      fb1 = FooBar.new
      fb2 = FooBar.new
      assert_raise(NoMethodError) { fb1.footsie(1, 2) }
      assert_raise(NoMethodError) { fb2.footsie(1, 2) }
      assert_equal true, fb1.__memoize_cache__.empty?
      assert_equal true, fb2.__memoize_cache__.empty?
      assert_equal 1, fb1.__send__(:footsie, 1, 2)
      assert_equal 2, fb2.__send__(:footsie, 1, 2)
      assert_equal 3, fb1.__send__(:footsie, 1, 2, 3)
      assert_equal 4, fb2.__send__(:footsie, 1, 2, 3)
      assert_equal 1, fb1.__send__(:footsie, 1, 2)
      assert_equal 2, fb2.__send__(:footsie, 1, 2)
      fb1.memoize_cache_clear
      fb2.memoize_cache_clear
      assert_equal true, fb1.__memoize_cache__.empty?
      assert_equal true, fb2.__memoize_cache__.empty?
      assert_equal 5, fb1.__send__(:footsie, 1, 2)
      assert_equal 6, fb2.__send__(:footsie, 1, 2)
      assert_equal 5, fb1.__send__(:footsie, 1, 2)
      assert_equal 6, fb2.__send__(:footsie, 1, 2)
      assert_equal false, fb1.__memoize_cache__.empty?
      assert_equal false, fb2.__memoize_cache__.empty?
    end

    def test_function_cache
      fb1 = FooBar.new
      fb2 = FooBar.new
      assert_equal 1, fb1.bar(1, 2)
      assert_equal 1, fb2.bar(1, 2)
      assert_equal 2, fb1.bar(1, 2, 3)
      assert_equal 2, fb2.bar(1, 2, 3)
      assert_equal 1, fb1.bar(1, 2)
      assert_equal 1, fb2.bar(1, 2)
      FooBar.memoize_cache_clear
      assert_equal 3, fb1.bar(1, 2)
      assert_equal 3, fb2.bar(1, 2)
      assert_equal false, FooBar.__memoize_cache__.empty?
    end

    def test_function_cache_private
      fb1 = FooBar.new
      fb2 = FooBar.new
      assert_raise(NoMethodError) { fb1.baz(1, 2) }
      assert_raise(NoMethodError) { fb2.baz(1, 2) }
      assert_equal 1, fb1.__send__(:baz, 1, 2)
      assert_equal 1, fb2.__send__(:baz, 1, 2)
      assert_equal 2, fb1.__send__(:baz, 1, 2, 3)
      assert_equal 2, fb2.__send__(:baz, 1, 2, 3)
      assert_equal 1, fb1.__send__(:baz, 1, 2)
      assert_equal 1, fb2.__send__(:baz, 1, 2)
      FooBar.memoize_cache_clear
      assert_equal 3, fb1.__send__(:baz, 1, 2)
      assert_equal 3, fb2.__send__(:baz, 1, 2)
      assert_equal false, FooBar.__memoize_cache__.empty?
    end
  end
end
