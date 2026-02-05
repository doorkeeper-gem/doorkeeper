require 'test_helper'

class DynamicScopeTest < Test::Unit::TestCase
  include Tins::DynamicScope

  def test_dynamic_scoping
    assert_raise(NameError) { foo }
    assert_equal false, dynamic_defined?(:foo)
    dynamic_scope do
      assert_raise(NameError) { foo }
      assert_equal false, dynamic_defined?(:foo)
      self.foo = 1
      assert_equal 1, foo
      assert_equal true, dynamic_defined?(:foo)
      dynamic_scope do
        assert_equal 1, foo
        assert_equal true, dynamic_defined?(:foo)
        self.foo = 2
        assert_equal 2, foo
        dynamic_scope do
          assert_equal 2, foo
        end
        assert_equal 2, foo
      end
      assert_equal 1, foo
    end
    assert_equal false, dynamic_defined?(:foo)
    assert_raise(NameError) { foo }
  end
end
