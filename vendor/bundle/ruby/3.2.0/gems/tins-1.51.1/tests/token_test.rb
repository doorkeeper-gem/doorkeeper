require 'test_helper'

module Tins
  class TokenTest < Test::Unit::TestCase
    def test_token_failures
      assert_raise(ArgumentError) { Tins::Token.new(bits: 0) }
      assert_raise(ArgumentError) { Tins::Token.new(length: 0) }
      assert_raise(ArgumentError) { Tins::Token.new(alphabet: %w[0]) }
    end

    def test_token_for_length
      token = Tins::Token.new(length: 22)
      assert_equal 22, token.length
      assert_equal 130, token.bits
    end

    def test_token_for_bits
      token = Tins::Token.new(bits: 128)
      assert_equal 22, token.length
      # can differ from bits argument depending on alphabet:
      assert_equal 130, token.bits
    end

    def test_alphabet
      token = Tins::Token.new(alphabet: %w[0 1])
      assert_equal 128, token.length
      assert_equal 128, token.bits
      token = Tins::Token.new(alphabet: %w[0 1 2 3])
      assert_equal 64, token.length
      assert_equal 128, token.bits
      token = Tins::Token.new(length: 128, alphabet: %w[0 1 2 3])
      assert_equal 128, token.length
      assert_equal 256, token.bits
    end

    def test_analyze_method
      # Test with default alphabet and length
      bits = Tins::Token.analyze(alphabet: Tins::Token::DEFAULT_ALPHABET, length: 22)
      assert_equal 130, bits

      # Test with hex alphabet and length
      bits = Tins::Token.analyze(alphabet: Tins::Token::BASE16_LOWERCASE_ALPHABET, length: 32)
      assert_equal 128, bits  # 32 × 4 = 128 bits

      # Test with base64 alphabet and length
      bits = Tins::Token.analyze(alphabet: Tins::Token::BASE64_ALPHABET, length: 44)
      assert_equal 264, bits  # 44 × 6 = 264 bits

      # Test with base32 alphabet and length
      bits = Tins::Token.analyze(alphabet: Tins::Token::BASE32_ALPHABET, length: 52)
      assert_equal 260, bits  # 52 × 5 = 260 bits

      # Test with token string instead of length
      token = "5f4dcc3b5aa765d61d8327deb882cf99"
      bits = Tins::Token.analyze(alphabet: Tins::Token::BASE16_LOWERCASE_ALPHABET, token: token)
      assert_equal 128, bits

      # Test error handling
      assert_raise(ArgumentError) do
        Tins::Token.analyze(alphabet: Tins::Token::DEFAULT_ALPHABET)
      end

      assert_raise(ArgumentError) do
        Tins::Token.analyze(alphabet: Tins::Token::DEFAULT_ALPHABET, token: "test", length: 5)
      end
    end
  end
end
