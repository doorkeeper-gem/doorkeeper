require 'test_helper'
require 'tins/xt'

module Tins
  class HashUnionTest < Test::Unit::TestCase

    class HashLike1
      def to_hash
        { 'foo' => true }
      end
    end

    class HashLike2
      def to_h
        { 'foo' => true }
      end
    end

    def test_union
      defaults = { 'foo' => true, 'bar' => false, 'quux' => nil }
      hash = { 'foo' => false }
      assert_equal [ ['bar', false], ['foo', false], ['quux', nil] ],
        (hash | defaults).sort
      hash |= defaults
      assert_equal [ ['bar', false], ['foo', false], ['quux', nil] ],
        hash.sort
      hash = { 'foo' => false }
      hash |= {
        'quux' => true,
        'baz' => 23,
      } | defaults
      assert_equal [ ['bar', false], [ 'baz', 23 ], ['foo', false],
        ['quux', true] ],
        hash.sort
    end

    def test_hash_conversion
      assert_equal({ 'foo' => true }, { } | HashLike1.new)
      assert_equal({ 'foo' => true }, { } | HashLike2.new)
    end
  end
end
