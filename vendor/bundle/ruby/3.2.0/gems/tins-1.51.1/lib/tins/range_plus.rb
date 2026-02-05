module Tins
  # RangePlus extends the Range class with additional functionality.
  #
  # This module adds a `+` method to Range objects that concatenates the
  # elements of two ranges into a single array.
  #
  # @example Basic usage
  #   range1 = (1..3)
  #   range2 = (4..6)
  #   result = range1 + range2
  #   # => [1, 2, 3, 4, 5, 6]
  #
  # @example With different range types
  #   range1 = ('a'..'c')
  #   range2 = ('d'..'f')
  #   result = range1 + range2
  #   # => ["a", "b", "c", "d", "e", "f"]
  #
  # @note This implementation converts both ranges to arrays and concatenates
  # them. This means it will materialize the entire range into memory, which
  # could be problematic for very large ranges.
  module RangePlus
    # Concatenates two ranges by converting them to arrays and merging them.
    #
    # This method allows you to combine the elements of two ranges into a
    # single array. Both ranges are converted to arrays using their `to_a`
    # method, then concatenated together.
    #
    # @param other [Range] Another range to concatenate with this range
    # @return [Array] A new array containing all elements from both ranges
    # @example
    #   (1..3) + (4..6)  # => [1, 2, 3, 4, 5, 6]
    def +(other)
      to_a + other.to_a
    end
  end
end
