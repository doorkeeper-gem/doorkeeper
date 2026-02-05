module Tins
  # A module that provides a predicate method for checking if a value matches
  # any of the given cases.
  module CasePredicate
    # Checks if the object matches any of the given arguments using the ===
    # operator.
    #
    # This method provides pattern matching functionality similar to Ruby's
    # case/when statements, using the === operator for semantic equality
    # checking.
    #
    # @example Basic type matching
    #   "hello".case?(String, Integer)     # => String (matches first argument)
    #   42.case?(String, Integer)          # => Integer (matches first argument)
    #   nil.case?(String, Integer)         # => nil (no matches)
    #
    # @example Range and pattern matching
    #   15.case?(1..10, 11..20, 21..30)    # => 11..20 (matches range)
    #   "hello world".case?(/foo/, /hello/) # => /hello/ (matches regex)
    #
    # @param args [Array] the arguments to check against using === operator
    # @return [Object, nil] the first matching argument, or nil if no match is
    # found
    def case?(*args)
      args.find { |a| a === self }
    end
  end
end
