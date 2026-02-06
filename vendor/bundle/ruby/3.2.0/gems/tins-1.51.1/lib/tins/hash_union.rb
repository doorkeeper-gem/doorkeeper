module Tins
  # A module that provides union functionality for hash-like objects
  #
  # This module implements the | (pipe) operator for hashes, allowing them to be
  # merged with other hash-like objects. The merge gives precedence to values from
  # the other object, making it useful for configuration merging where default
  # values should be overridden by user-provided options.
  module HashUnion
    # Implements the | (union) operator for hash-like objects.
    #
    # Merges another hash-like object into this object, with the other taking
    # precedence over self. This is useful for configuration merging where
    # default values should be overridden by user-provided options.
    #
    # @example Basic usage
    #   h1 = { a: 1, b: 2 }
    #   h2 = { b: 3, c: 4 }
    #   result = h1 | h2
    #   # => { a: 1, b: 3, c: 4 }  # h2 values take precedence
    #
    # @example Configuration merging
    #   default_options = {
    #     format: :json,
    #     timeout: 30,
    #     retries: 3
    #   }
    #
    #   user_options = { timeout: 60 }
    #   options = user_options | default_options
    #   # => { format: :json, timeout: 60, retries: 3 }
    #
    # @example With objects that respond to to_hash
    #   class CustomHash
    #     def to_hash
    #       { x: 10, y: 20 }
    #     end
    #   end
    #
    #   custom = CustomHash.new
    #   result = { a: 1 } | custom
    #   # => { a: 1, x: 10, y: 20 }
    #
    # @param other [Hash, Object] Another hash-like object to merge with.
    #   Can be a Hash, or any object that responds to either `to_hash` or `to_h`.
    # @return [Hash] A new hash containing the merged key-value pairs
    #
    # @note The merge operation preserves the original hashes and returns a new
    # hash. In case of duplicate keys, values from `other` will overwrite
    # values from `self`.
    def |(other)
      case
      when other.respond_to?(:to_hash)
        other = other.to_hash
      when other.respond_to?(:to_h)
        other = other.to_h
      end
      other.merge(self)
    end
  end
end
