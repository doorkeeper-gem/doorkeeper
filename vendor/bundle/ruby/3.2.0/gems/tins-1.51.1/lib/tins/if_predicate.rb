module Tins
  # A module that provides a predicate method for checking if a value is
  # truthy.
  #
  # The IfPredicate module adds a #if? method to objects that returns true if
  # the object is truthy, and false if it is falsy. This is useful for
  # conditional logic where you want to check if
  # an object evaluates to true in a boolean context.
  module IfPredicate
    # A predicate method that returns the receiver if it's truthy,
    # or nil if it's falsy.
    #
    # This method is designed to work in conditional expressions
    # where you want to check if a value is truthy and either
    # return it or handle the falsy case.
    #
    # @example Basic usage
    #   true.if?     # => true
    #   false.if?    # => nil
    #   nil.if?      # => nil
    #   "hello".if?  # => "hello"
    #   "".if?       # => ""
    #
    # @example With default values
    #   user = nil
    #   name = user.if? || "Anonymous"
    #   # => "Anonymous"
    #
    #   user = "John"
    #   name = user.if? || "Anonymous"
    #   # => "John"
    #
    # @return [Object, nil] The receiver if truthy, nil if falsy
    def if?
      self ? self : nil
    end
  end
end
