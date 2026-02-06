module Tins
  # Tins::Minimize provides methods for compressing sequential data into ranges
  # and expanding ranges back into individual elements.
  #
  # This module is designed for objects that respond to `[]` and `size` methods,
  # such as Array, and whose elements respond to the `succ` method (like String
  # and Numeric types). It's particularly useful for representing sequential data
  # more compactly and efficiently.
  #
  # @example Basic minimization
  #   [ 'A', 'B', 'C', 'G', 'K', 'L', 'M' ].minimize
  #   # => [ 'A'..'C', 'G'..'G', 'K'..'M' ]
  #
  # @example Numeric minimization
  #   [ 1, 2, 3, 7, 9, 10, 11 ].minimize
  #   # => [ 1..3, 7..7, 9..11 ]
  #
  # @example Sorting before minimization
  #   [ 5, 1, 4, 2 ].sort.minimize
  #   # => [ 1..2, 4..5 ]
  #
  # @example Unminimization
  #   [ 'A'..'C', 'G'..'G', 'K'..'M' ].unminimize
  #   # => [ 'A', 'B', 'C', 'G', 'K', 'L', 'M' ]
  module Minimize
    # Returns a minimized version of this object, that is successive elements
    # are substituted with ranges a..b. In the situation ..., x, y,... and y !=
    # x.succ a range x..x is created, to make it easier to iterate over all the
    # ranges in one run.
    #
    # @return [Array<Range>] An array of ranges representing the minimized data
    # @example Sequential string elements
    #   [ 'A', 'B', 'C', 'G', 'K', 'L', 'M' ].minimize
    #   # => [ 'A'..'C', 'G'..'G', 'K'..'M' ]
    #
    # @example Numeric elements
    #   [ 1, 2, 3, 7, 9, 10, 11 ].minimize
    #   # => [ 1..3, 7..7, 9..11 ]
    def minimize
      result     = []
      last_index = size - 1
      size.times do |i|
        result << [ self[0] ] if i == 0
        if self[i].succ != self[i + 1] or i == last_index
          result[-1] << self[i]
          result << [ self[i + 1] ] unless i == last_index
        end
      end
      result.map! { |a, b| a..b }
    end

    # First minimizes this object, then calls the replace method with the
    # result.
    #
    # @return [Object] Returns self (modified in place)
    def minimize!
      replace minimize
    end

    # Invert a minimized version of an object. Some small examples:
    #  [ 'A'..'C', 'G'..'G', 'K'..'M' ].unminimize # => [ 'A', 'B', 'C', 'G', 'K', 'L', 'M' ]
    # and
    #  [ 1..2, 4..5 ].unminimize # => [ 1, 2, 4, 5 ]
    #
    # @return [Array] An array of individual elements expanded from ranges
    def unminimize
      result = []
      for range in self
        for e in range
          result << e
        end
      end
      result
    end

    # Invert a minimized version of this object in place.
    #
    # @return [Object] Returns self (modified in place)
    def unminimize!
      replace unminimize
    end
  end
end
