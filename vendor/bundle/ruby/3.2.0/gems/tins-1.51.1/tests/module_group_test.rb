require 'test_helper'

module Tins
  class ModuleGroupTest < Test::Unit::TestCase
    MyClasses = Tins::ModuleGroup[ Array, String, Hash ]

    def test_module_group
      assert MyClasses === []
      assert MyClasses === ""
      assert MyClasses === {}
      assert !(MyClasses === :nix)
      case []
      when MyClasses
        assert true
      when Array
        assert false
      end
      case :nix
      when MyClasses
        assert false
      when Array
        assert false
      when Symbol
        assert true
      end
    end
  end
end
