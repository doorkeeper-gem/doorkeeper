require 'test_helper'

class SexySingletonTest < Test::Unit::TestCase
  class Single
    include Tins::SexySingleton

    def foo
      :foo
    end
  end

  def test_foo
    assert_equal :foo, Single.instance.foo
    assert_equal :foo, Single.foo
  end
end
