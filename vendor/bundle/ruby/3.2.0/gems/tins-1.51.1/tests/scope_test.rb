require 'test_helper'

class ScopeTest < Test::Unit::TestCase
  include Tins::Scope

  def test_default_scope
    scope_block(:foo) do
      assert_equal [ :foo ], scope
      scope_block(:bar) do
        assert_equal [ :foo, :bar ], scope
        scope.push :baz
        assert_equal [ :foo, :bar ], scope
      end
    end
  end

  def test_two_scopes
    scope_block(:foo, :my_scope) do
      assert_equal [ :foo ], scope(:my_scope)
      scope_block(:baz) do
        scope_block(:bar, :my_scope) do
          assert_equal [ :foo, :bar ], scope(:my_scope)
          scope.push(:baz)
          assert_equal [ :foo, :bar ], scope(:my_scope)
          assert_equal [ :baz ], scope
        end
      end
    end
  end
end
