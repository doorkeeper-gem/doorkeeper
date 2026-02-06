require 'test_helper'

module Tins
  class SubhashTest < Test::Unit::TestCase
    require 'tins/xt/subhash'

    def test_subhash
      h = { 'foo1' => 1, 'foo2' => 2, 'bar666' => 666 }
      assert_equal [ [ 'bar666', 666 ] ], h.subhash(/\Abar/).to_a
      assert h.subhash(/\Abaz/).empty?
      assert_equal [ [ 'foo1', 1 ], [ 'foo2', 2 ] ], h.subhash(/\Afoo\d/).sort
      assert_equal [ [ 'foo2', 2 ] ], h.subhash('foo2').to_a
    end

    def test_subhash_bang
      h = { 'foo1' => 1, 'foo2' => 2, 'bar666' => 666 }
      h.subhash!('foo2')
      assert_equal [ [ 'foo2', 2 ] ], h.to_a
    end

    def test_subhash_with_block
      h = { 'foo1' => 1, 'foo2' => 2, 'bar666' => 666 }
      assert h.subhash(/\Abaz/) { :foo }.empty?
      assert_equal [ [ 'foo1', 1 ], [ 'foo2', 2 ] ],
        h.subhash(/\Afoo(\d)/) { |_,_,m| Integer(m[1]) }.to_a.sort
    end

    def test_subhash_with_default_proc
      hash = Hash.new { |h, k| h[k] = :foo }
      hash.update('foo' => 1, 'bar' => 2)
      s = hash.subhash('foo')
      assert_equal 1, s['foo']
      assert_equal :foo, s['bar']
    end
  end
end
