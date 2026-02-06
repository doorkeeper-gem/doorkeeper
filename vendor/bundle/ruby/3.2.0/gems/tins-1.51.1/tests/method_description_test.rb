require 'test_helper'
require 'tins/xt'

module Tins
  class MethodDescriptionTest < Test::Unit::TestCase
    class A
      def foo
      end

      def self.foo
      end
    end

    def test_static_nonstatic
      assert_equal 'Tins::MethodDescriptionTest::A#foo()', A.instance_method(:foo).description
      assert_equal 'Tins::MethodDescriptionTest::A.foo()', A.method(:foo).description
    end

    class B
      def foo(x, y = 1, *r, &b)
      end

      def bar(x, y = 2, *r, &b)
      end

      def bar2(x, z = 2, *r, &b)
      end

      def baz(x, y = 2, z = 3, *r, &b)
      end
    end

    def test_standard_parameters_namespace
      assert_equal 'Tins::MethodDescriptionTest::B#foo(x,y=…,*r,&b)',
        B.instance_method(:foo).description
    end

    def test_standard_parameters_name
      assert_equal 'foo(x,y=…,*r,&b)',
        B.instance_method(:foo).description(style: :name)
    end

    def test_standard_parameters_signature
      assert_kind_of Tins::MethodDescription::Signature,
        B.instance_method(:foo).signature
    end

    def test_signature_equalitites
      assert_equal(
        B.instance_method(:foo).signature,
        B.instance_method(:bar).signature
      )
      assert_equal(
        B.instance_method(:foo).signature,
        B.instance_method(:bar2).signature
      )
      assert_false\
        B.instance_method(:foo).signature.eql?(
          B.instance_method(:bar2).signature
        )
      assert_operator(
        B.instance_method(:foo).signature,
        :===,
        B.instance_method(:bar2)
      )
      assert_not_equal(
        B.instance_method(:bar).signature,
        B.instance_method(:baz).signature
      )
    end

    def test_a_cstyle_method_from_hash
      assert_equal "Hash#store(x1,x2)", ({}.method(:store).description)
    end

    class C
      def foo(x, k: true, &b)
      end

      def bar(x, **k, &b)
      end
    end

    def test_keyword_parameters
      assert_equal 'Tins::MethodDescriptionTest::C#foo(x,k:…,&b)', C.instance_method(:foo).description
      assert_equal 'Tins::MethodDescriptionTest::C#bar(x,**k,&b)', C.instance_method(:bar).description
    end

    class D
      def foo(x, k:, &b)
      end
    end

    def test_keyword_parameters_required
      assert_equal 'Tins::MethodDescriptionTest::D#foo(x,k:,&b)', D.instance_method(:foo).description
    end
  end
end
