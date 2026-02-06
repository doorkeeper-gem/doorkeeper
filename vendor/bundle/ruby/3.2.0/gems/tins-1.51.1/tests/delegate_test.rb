require 'test_helper'


class DelegationTestClass
  class DelegationTestClass2
    def self.size
      5
    end
  end

  extend Tins::Delegate

  def self.size
    1
  end

  @@ary = [ 1, 2 ]

  def initialize
    @ary = [ 1, 2, 3 ]
  end

  def ary
    [ 1, 2, 3, 4 ]
  end

  delegate :size, to: :class

  delegate :size, to: :@@ary, as: 'cvar_size'

  delegate :size, to: :@ary, as: 'ivar_size'

  delegate :size, to: :ary, as: 'method_size'

  delegate :size, to: 'DelegationTestClass::DelegationTestClass2',
    as: 'class_size'
end

class DelegateTest < Test::Unit::TestCase
  def test_delegate
    d = DelegationTestClass.new
    assert_equal 1, d.size
    assert_equal 2, d.cvar_size
    assert_equal 3, d.ivar_size
    assert_equal 4, d.method_size
    assert_equal 5, d.class_size
  end
end
