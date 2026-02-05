require 'test_helper'
require 'tins/xt/expose'

module Tins
  class ExposeTest < Test::Unit::TestCase
    class A
      def priv
        :priv
      end
      private :priv

      def prot(x)
        :prot
      end
      protected :prot
    end

    def setup
      @a = A.new
    end

    def test_raises_exception_unless_exposed
      assert_raise(NoMethodError) { @a.priv }
      assert_raise(NoMethodError) { @a.prot(:any) }
    end

    def test_exposes_all_methods
      @a = @a.expose
      assert_equal :priv, @a.priv
      assert_equal :prot, @a.prot(:any)
    end

    def test_exposes_all_methods_in_block
      assert_equal :priv, @a.expose { priv }
      assert_equal :prot, @a.expose { prot(:any) }
    end

    def test_exposes_specified_method_call
      assert_equal :priv, @a.expose(:priv)
      assert_equal :prot, @a.expose(:prot, :any)
    end
  end
end
