require 'test_helper'
require 'tins/xt/proc_prelude'

module Tins
  class ProcPreludeTest < Test::Unit::TestCase
    def test_apply
      assert_equal 42,
        Proc.apply { |x, y, z|  x ** 2 + y ** 3 + z ** 5 }.call([3, 1, 2])
    end

    class Person
      def initialize(name)
        @name = name
      end

      attr_reader :name
    end

    def test_map_apply
      ps = %w[anne bernd christian].map { |n| Person.new(n) }

      i = 0
      assert_equal %w[ anne1 bernd2 christian3 ],
        ps.reduce([], &Proc.map_apply(:name) { |s, n| s << "#{n}#{i += 1}" })
    end

    def test_call
      def (o = Object.new).foo
        :foo
      end
      assert_equal :foo, Proc.call(o) { foo }
    end

    def test_array
      assert_equal [1,2,3], Proc.array.call(1,2,3)
    end

    def test_first
      assert_equal 1, Proc.first.call(1,2,3)
      assert_equal 1, Proc.head.call(1,2,3)
    end

    def test_second
      assert_equal 2, Proc.second.call(1,2,3)
    end

    def test_tail
      assert_equal [ 2, 3 ], Proc.tail.call(1,2,3)
    end

    def test_last
      assert_equal 3, Proc.last.call(1,2,3)
    end

    def test_rotate
      assert_equal [ 2, 3, 1 ], Proc.rotate.call(1,2,3)
      assert_equal [ 2, 1 ], Proc.swap.call(1,2)
    end

    def test_id1
      assert_equal :foo, Proc.id1.call(:foo)
    end

    def test_const
      assert_equal :baz, Proc.const(:baz).call(:foo, :bar)
      assert_equal :baz, Proc.const { :baz }.call(:foo, :bar)
    end

    def test_nth
      assert_equal 2, Proc.nth(1).call(1,2,3)
    end

    def square(x)
      x ** 2
    end

    def test_from
      assert_equal [ 1, 4, 9 ], [ 1, 2, 3 ].map(&Proc.from{:square})
    end
  end
end
