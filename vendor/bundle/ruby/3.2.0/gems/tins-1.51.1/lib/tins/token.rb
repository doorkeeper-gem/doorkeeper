require 'securerandom'

module Tins
  # A secure token generator that creates cryptographically safe strings
  # using customizable alphabets and random number generators.
  #
  # @example Basic usage
  #   token = Tins::Token.new
  #   # => "aB3xK9mN2pQ8rS4tU6vW7yZ1"
  #
  # @example Custom length
  #   token = Tins::Token.new(length: 20)
  #   # => "xYz123AbC456DeF789GhI0jK"
  #
  # @example Custom alphabet
  #   token = Tins::Token.new(
  #     alphabet: Tins::Token::BASE16_UPPERCASE_ALPHABET,
  #     length: 16
  #   )
  #   # => "A1B2C3D4E5F6G7H8"
  #
  # @example Custom random number generator
  #   token = Tins::Token.new(random: Random.new(42))
  #   # => "xYz123AbC456DeF789GhI0jK"
  class Token < String
    # Default alphabet for token generation
    DEFAULT_ALPHABET =
      "0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ".freeze

    # Base64 alphabet
    BASE64_ALPHABET =
      "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/".freeze

    # URL-safe base64 alphabet
    BASE64_URL_FILENAME_SAFE_ALPHABET =
      "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_".freeze

    # Base32 alphabet
    BASE32_ALPHABET = "ABCDEFGHIJKLMNOPQRSTUVWXYZ234567".freeze

    # Extended hex base32 alphabet
    BASE32_EXTENDED_HEX_ALPHABET = "0123456789ABCDEFGHIJKLMNOPQRSTUV".freeze

    # Base16 uppercase alphabet
    BASE16_UPPERCASE_ALPHABET = "0123456789ABCDEF".freeze

    # Base16 lowercase alphabet
    BASE16_LOWERCASE_ALPHABET = "0123456789abcdef".freeze

    # Base16 default alphabet (uppercase)
    BASE16_ALPHABET = BASE16_UPPERCASE_ALPHABET

    # Initializes a new Token instance with specified bit length, length,
    # alphabet, and random number generator.
    #
    # @example Basic initialization
    #   token = Tins::Token.new
    #   # => "aB3xK9mN2pQ8rS4tU6vW7yZ1"
    #
    # @example Custom parameters
    #   token = Tins::Token.new(
    #     bits: 256,
    #     alphabet: Tins::Token::BASE32_ALPHABET
    #   )
    #
    # @param bits [Integer] the number of bits for the token (default: 128)
    # @param length [Integer] the length of the token (optional, mutually exclusive with bits)
    # @param alphabet [String] the alphabet to use for token generation (default: DEFAULT_ALPHABET)
    # @param random [Object] the random number generator to use (default: SecureRandom)
    #
    # @return [Tins::Token] a new Token instance
    #
    # @raise [ArgumentError] if alphabet has fewer than 2 symbols
    # @raise [ArgumentError] if bits is not positive when length is not specified
    # @raise [ArgumentError] if length is not positive when specified
    def initialize(bits: 128, length: nil, alphabet: DEFAULT_ALPHABET, random: SecureRandom)
      alphabet.size > 1 or raise ArgumentError, 'need at least 2 symbols in alphabet'
      if length
        length > 0 or raise ArgumentError, 'length has to be positive'
      else
        bits > 0 or raise ArgumentError, 'bits has to be positive'
        length = (Math.log(1 << bits) / Math.log(alphabet.size)).ceil
      end
      self.bits = self.class.analyze(alphabet:, length:)
      token = +''
      length.times { token << alphabet[random.random_number(alphabet.size)] }
      super token
    end

    # The bit length of the token.
    #
    # @return [Integer] the number of bits of entropy in the token
    attr_accessor :bits

    # The analyze method calculates the bit length of a token based on its
    # alphabet and length.
    #
    # @param alphabet [String] the alphabet used for token generation, defaults
    #   to Tins::Token::DEFAULT_ALPHABET
    # @param token [String, nil] the token string to analyze, optional
    # @param length [Integer, nil] the length of the token, optional
    #
    # @return [Integer] the calculated bit length of the token
    #
    # @raise [ArgumentError] if neither token nor length is provided, or if both are provided
    def self.analyze(alphabet: Tins::Token::DEFAULT_ALPHABET, token: nil, length: nil)
      token.nil? ^ length.nil? or raise ArgumentError, 'either token or length is required'
      length ||= token.length
      (Math.log(alphabet.size ** length) / Math.log(2)).floor
    end
  end
end
