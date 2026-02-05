require 'test_helper'
require 'tins/xt/hash_bfs'

module Tins
  class HashBFSTest < Test::Unit::TestCase
    def setup
      @hash = { a: 'foo', b: [ { c: 'baz' }, { d: 'quux' }, [ 'blub' ] ] }
    end

    def test_without_nodes
      results = []
      @hash.bfs { |*a| results.push(a) }
      assert_equal [[:a, "foo"], [:c, "baz"], [:d, "quux"], [0, "blub"]], results
    end

    def test_with_nodes
      results = []
      @hash.bfs(visit_internal: true) { |*a| results.push(a) }
      assert_equal(
        [[nil, {a:"foo", b:[{c:"baz"}, {d:"quux"}, ["blub"]]}], [:a, "foo"],
         [:b, [{c:"baz"}, {d:"quux"}, ["blub"]]], [0, {c:"baz"}], [1, {d:"quux"}],
         [2, ["blub"]], [:c, "baz"], [:d, "quux"], [0, "blub"]], results
      )
      assert_equal 9, results.size
    end

    def test_with_nodes_with_circle
      results = []
      @hash[:b].last << @hash
      @hash.bfs(visit_internal: true) { |*a| results.push(a) }
      assert_equal 9, results.size
    end
  end
end
