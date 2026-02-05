require 'test_helper'

module Tins
  class ImplementTest < Test::Unit::TestCase
    require 'tins/xt/implement'

    class A
      implement :foo

      implement :bar, in: :subclass

      implement :baz, in: :submodule

      implement :qux, 'blub %{method_name} blob %{module}'

      implement :quux, 'blab'

      implement def foobar(arg1, arg2: :baz)
      end, in: :subclass
    end

    def test_implement_default
      assert_equal(
        'method foo not implemented in module Tins::ImplementTest::A',
        error_message { A.new.foo }
      )
    end

    def test_implement_subclass
      assert_equal(
        'method bar has to be implemented in subclasses of '\
        'Tins::ImplementTest::A',
        error_message { A.new.bar }
      )
    end

    def test_implement_submodule
      assert_equal(
        'method baz has to be implemented in submodules of '\
        'Tins::ImplementTest::A',
        error_message { A.new.baz }
      )
    end

    def test_implement_custom_with_vars
      assert_equal(
        'blub qux blob Tins::ImplementTest::A',
        error_message { A.new.qux }
      )
    end

    def test_implement_custom_without_vars
      assert_equal('blab', error_message { A.new.quux })
    end

    def test_implement_def_subclass
      assert_equal(
        'method foobar(arg1,arg2:…) has to be '\
        'implemented in subclasses of Tins::ImplementTest::A',
        error_message { A.new.foobar }
      )
    end

    private

    def error_message
      yield
    rescue NotImplementedError => e
      e.message
    end
  end
end
