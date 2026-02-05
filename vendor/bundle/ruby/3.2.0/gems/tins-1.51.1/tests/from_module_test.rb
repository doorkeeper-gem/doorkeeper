require 'test_helper'

class FromModuleTest < Test::Unit::TestCase
  module MyIncludedModule
    def foo
      :foo
    end

    def bar
      :bar
    end
  end

  module MyIncludedModule2
    def foo
      :foo2
    end

    def bar
      :bar2
    end
  end

  class MyKlass
    def foo
      :original_foo
    end

    def bar
      :original_bar
    end
  end

  class DerivedKlass < MyKlass
    extend Tins::FromModule

    include from module: MyIncludedModule, methods: [ :foo ]
  end

  module MyModule
    def foo
      :original_foo
    end

    def bar
      :original_bar
    end

    def baz
      :original_baz
    end
    include MyIncludedModule
  end

  class AnotherDerivedKlass
    extend Tins::FromModule

    include MyModule
    include from module: MyIncludedModule, methods: :foo
  end

  def test_derived_klass
    c = DerivedKlass.new
    assert_equal :foo, c.foo
    assert_equal :original_bar, c.bar
  end

  def test_another_derived_klass
    c = AnotherDerivedKlass.new
    assert_equal :foo, c.foo
    assert_equal :original_bar, c.bar
  end

  class MixedClass
    extend Tins::FromModule

    include MyModule
    include from module: MyIncludedModule, methods: :foo
    include from module: MyIncludedModule2, methods: :bar
  end

  def test_mixed_klass
    c = MixedClass.new
    assert_equal :foo, c.foo
    assert_equal :bar2, c.bar
    assert_equal :original_baz, c.baz
  end
end
