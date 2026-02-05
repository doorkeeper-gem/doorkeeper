require 'test_helper'

module Tins
  class GoTest < Test::Unit::TestCase
    include Tins::GO

    def test_empty_string
      r = go '', args = %w[a b c]
      assert_equal({}, r)
      assert_equal %w[a b c], args
    end

    def test_empty_args
      r = go 'ab:', args = []
      assert_equal({ 'a' => false, 'b' => nil }, r)
      assert_equal [], args
    end

    def test_simple
      r = go 'ab:', args = %w[-b hello -a -c rest]
      assert_equal({ 'a' => 1, 'b' => 'hello' }, r)
      assert_equal %w[-c rest], args
    end

    def test_complex
      r = go 'ab:', args = %w[-a -b hello -a -bworld -c rest]
      assert_equal({ 'a' => 2, 'b' => 'hello' }, r)
      assert_equal %w[hello world], r['b'].to_a
      assert_equal %w[-c rest], args
    end

    def test_complex2
      r = go 'ab:', args = %w[-b hello -aa -b world -c rest]
      assert_equal({ 'a' => 2, 'b' => 'hello' }, r)
      assert_equal %w[hello world], r['b'].to_a
      assert_equal %w[-c rest], args
    end

    def test_complex_frozen
      args = %w[-b hello -aa -b world -c rest]
      args = args.map(&:freeze)
      r = go 'ab:', args
      assert_equal({ 'a' => 2, 'b' => 'hello' }, r)
      assert_equal %w[hello world], r['b'].to_a
      assert_equal %w[-c rest], args
    end

    def test_mixed_rest
      r = go 'ab:e:', args = %w[-b hello -c rest -aa -b world -d rest -e]
      assert_equal({ 'a' => 2, 'b' => 'hello', 'e' => nil }, r)
      assert_equal %w[hello world], r['b'].to_a
      assert_equal %w[-c rest -d rest -e], args
    end

    def test_concatenated_argument_at_end
      r = go 'ab:e:', args = %w[-a -bhello]
      assert_equal({ 'a' => 1, 'b' => 'hello', 'e' => nil }, r)
      assert_equal [], args
    end

    def test_defaults
      r = go('bv:w:', args = %w[ -v bar ], defaults: { ?b => true, ?v => 'foo', ?w => 'baz' })
      assert_equal({ ?b => 1, 'v' => 'bar', 'w' => 'baz' }, r)
      assert_kind_of(Tins::GO::ArrayExtension, r[?v])
      assert_kind_of(Tins::GO::ArrayExtension, r[?w])
      assert_equal [], args
      r = go('bv:', args = %w[ -v bar ~b baz ], defaults: { ?b => true, ?v => 'foo' })
      assert_equal({ ?b => false, 'v' => 'bar' }, r)
      assert_equal %w[ baz ], args
      r = go('bv:', args = %w[ -b -v bar ], defaults: { ?b => 22, ?v => 'foo' })
      assert_equal({ ?b => 23, 'v' => 'bar' }, r)
      assert_equal [], args
      r = go('bv:', args = %w[ -b ], defaults: { ?b => false, ?v => 'foo' })
      assert_equal({ ?b => 1, 'v' => 'foo' }, r)
      assert_equal [], args
      r = go('bv:', args = %w[ ], defaults: { ?b => false, ?v => 'foo' })
      assert_equal({ ?b => false, 'v' => 'foo' }, r)
      assert_equal [], args
    end
  end
end
