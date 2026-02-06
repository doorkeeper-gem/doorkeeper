require 'test_helper'

module Tins
  class LRUCacheTest < Test::Unit::TestCase
    def setup
      @cache = LRUCache.new(3)
    end

    def test_too_low_capacity
      ex = assert_raise ArgumentError do
        LRUCache.new(0)
      end
      assert_equal 'capacity should be >= 1, was 0', ex.message
    end

    def test_wrong_capacity_type
      assert_raise TypeError do
        LRUCache.new(:foo)
      end
    end

    def test_can_be_filled_to_capacity
      assert_equal 0, @cache.size
      @cache[1] = 1
      assert_equal 1, @cache.size
      @cache[2] = 2
      assert_equal 2, @cache.size
      @cache[3] = 3
      assert_equal 3, @cache.size
      @cache[4] = 4
      assert_equal 3, @cache.size
      assert_equal 4, @cache.first[0]
    end

    def test_reorders_based_on_recency
      (1..3).each do |i|
        @cache[i] = i
      end
      assert_equal 3, @cache.first[0]
      @cache[1]
      assert_equal 1, @cache.first[0]
    end

    def test_can_be_cleared
      (1..3).each do |i|
        @cache[i] = i
      end
      assert_equal 3, @cache.size
      @cache.clear
      assert_equal 0, @cache.size
    end

    def test_can_be_deleted_from
      (1..3).each do |i|
        @cache[i] = i
      end
      assert_equal 3, @cache.size
      @cache.delete 2
      assert_equal 2, @cache.size
      assert_nil @cache[2]
    end
  end
end
