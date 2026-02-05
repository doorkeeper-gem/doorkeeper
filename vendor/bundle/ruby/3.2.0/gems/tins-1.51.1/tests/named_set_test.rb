require 'test_helper'

module Tins
  class NamedSetTest < Test::Unit::TestCase
    class ThingsTodo < Tins::NamedSet
    end

    def test_named_set
      s = ThingsTodo.new('list')
      assert_equal 'list', s.name
      s << 'Get up'
      s << 'Shower'
      s << 'Shave'
      assert_equal 3, s.size
    end
  end
end
