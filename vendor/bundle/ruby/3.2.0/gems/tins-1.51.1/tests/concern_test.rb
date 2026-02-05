require 'test_helper'

class ConcernTest < Test::Unit::TestCase
  module C1
    extend Tins::Concern

    included do
      $included = self
    end

    prepended do
      $prepended = self
    end

    def foo
      :foo
    end

    class_methods do
      def baz1
        :baz1
      end
    end

    module ClassMethods
      def bar
        :bar
      end
    end

    class_methods do
      def baz2
        :baz2
      end
    end
  end

  $included = nil
  $prepended = nil

  module C2
    extend Tins::Concern

    def foo
      :'prepended-foo'
    end
  end


  class A
    include C1
  end

  class B
    prepend C1
  end

  class C
    def foo
      :foo
    end
  end

  def test_concern_include
    a = A.new
    assert_equal A, $included
    assert_equal :foo, a.foo
    assert_equal :bar, A.bar
    assert_equal :baz1, A.baz1
    assert_equal :baz2, A.baz2
    assert_raise(StandardError) do
      C1.module_eval { included {} }
    end
  end

  def test_concern_prepend
    b = B.new
    assert_equal B, $prepended
    assert_equal :foo, b.foo
    assert_equal :bar, B.bar
    assert_equal :baz1, B.baz1
    assert_equal :baz2, B.baz2
    assert_raise(StandardError) do
      C1.module_eval { prepended {} }
    end
  end

  def test_prepended_method
    c = C.new
    assert_equal :foo, c.foo
    C.class_eval { prepend C2 }
    assert_equal :'prepended-foo', c.foo
  end
end
