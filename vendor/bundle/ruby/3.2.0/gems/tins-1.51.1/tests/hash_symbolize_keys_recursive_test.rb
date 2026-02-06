require 'test_helper'

module Tins
  class HashSymbolizeKeysRecursiveTest < Test::Unit::TestCase
    require 'tins/xt/hash_symbolize_keys_recursive'

    def test_symbolize
      hash = {
        'key' => [
          {
            'key' => {
              'key' => true
            },
            'o' => Object.new,
          }
        ],
      }
      hash2 = hash.symbolize_keys_recursive
      assert hash2[:key][0][:key][:key]
      hash.symbolize_keys_recursive!
      assert hash[:key][0][:key][:key]
    end

    def test_symbolize_bang
      hash = { 'foo' => 'bar' }
      hash.symbolize_keys_recursive!
      assert_equal({ foo: 'bar' }, hash)
    end

    def test_symbolize_with_circular_array
      circular_array = [].tap { |a| a << a }
      assert_equal(
        { foo: [ nil ] },
        { 'foo' => circular_array }.symbolize_keys_recursive
      )
      assert_equal(
        { foo: [ :circular ] },
        { 'foo' => circular_array }.symbolize_keys_recursive(circular: :circular)
      )
    end

    def test_symbolize_with_circular_hash
      circular_hash = {}.tap { |h| h['foo'] = h }
      circular_hash_symbol = {}.tap { |h| h[:foo] = nil }
      assert_equal(
        { bar: circular_hash_symbol },
        { 'bar' => circular_hash }.symbolize_keys_recursive
      )
      assert_equal(
        { bar: { foo: :circular } },
        { 'bar' => circular_hash }.symbolize_keys_recursive(circular: :circular)
      )
    end

    def test_symbolize_deeper_nesting
      hash = { 'foo' => [ true, [ { 'bar' => {}.tap { |h| h['foo'] = h } }, 3.141, [].tap { |arr| arr << arr } ] ] }
      assert_equal(
        {foo: [true, [{bar: {foo: :circular}}, 3.141, [:circular]]]},
        hash.symbolize_keys_recursive(circular: :circular)
      )
    end
  end
end
