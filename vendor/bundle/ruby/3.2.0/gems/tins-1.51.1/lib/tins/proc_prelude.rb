require 'tins/memoize'

module Tins
  # Tins::ProcPrelude provides a set of utility methods for creating and composing
  # Proc objects with common functional programming patterns.
  #
  # This module contains various helper methods that return lambda functions,
  # making it easier to build complex processing pipelines and functional
  # transformations. These are particularly useful in functional programming
  # contexts or when working with higher-order functions.
  #
  # The methods are typically accessed through the singleton interface:
  #   Proc.array.(1, 2, 3)  # => [1, 2, 3]
  #
  # @example Basic usage with map_apply in reduce context
  #   # Create a proc that applies a method to each element and accumulates results
  #   proc = Proc.map_apply(:upcase) { |s, upcased| s << upcased }
  #
  #   # Use it with Array#reduce
  #   ['hello', 'world'].reduce([], &proc)
  #   # => ['HELLO', 'WORLD']
  #
  # @example Using array to convert arguments to list
  #   proc = Proc.array
  #   proc.(1, 2, 3)
  #   # => [1, 2, 3]
  module ProcPrelude
    # Create a proc that applies the given block to a list of arguments.
    #
    # @yield [list] The block to apply to the arguments
    # @return [Proc] A proc that takes arguments and calls the block with them unpacked
    def apply(&my_proc)
      my_proc or raise ArgumentError, 'a block argument is required'
      lambda { |list| my_proc.(*list) }
    end

    # Create a proc that applies a method to an object and then applies the block.
    #
    # @param my_method [Symbol] The method name to call on each element
    # @param args [Array] Additional arguments to pass to the method
    # @yield [x, y] The block to apply after calling the method
    # @return [Proc] A proc that takes two arguments and applies the method + block
    # @raise [ArgumentError] if no block is provided
    def map_apply(my_method, *args, &my_proc)
      my_proc or raise ArgumentError, 'a block argument is required'
      lambda { |x, y| my_proc.(x, y.__send__(my_method, *args)) }
    end

    # Create a proc that evaluates a block in the context of an object.
    #
    # @param obj [Object] The object to evaluate the block against
    # @yield [obj] The block to evaluate in the object's context
    # @return [Proc] A proc that takes an object and evaluates the block
    def call(obj, &my_proc)
      my_proc or raise ArgumentError, 'a block argument is required'
      obj.instance_eval(&my_proc)
    end

    # Create a proc that converts all arguments to a list array.
    #
    # @return [Proc] A proc that takes any number of arguments and returns them as a list
    def array
      lambda { |*list| list }
    end
    memoize function: :array, freeze:  true

    # Create a proc that returns the first element (the head) of a list.
    #
    # @return [Proc] A proc that takes a list and returns its first element
    def first
      lambda { |*list| list.first }
    end
    memoize function: :first, freeze:  true

    alias head first

    # Create a proc that returns the second element of a list.
    #
    # @return [Proc] A proc that takes a list and returns its second element
    def second
      lambda { |*list| list[1] }
    end
    memoize function: :second, freeze:  true

    # Create a proc that returns all elements except the first (the tail) from
    # a list.
    #
    # @return [Proc] A proc that takes a list and returns all but the first element
    def tail
      lambda { |*list| list[1..-1] }
    end
    memoize function: :tail, freeze:  true

    # Create a proc that returns the last element of a list.
    #
    # @return [Proc] A proc that takes a list and returns its last element
    def last
      lambda { |*list| list.last }
    end
    memoize function: :last, freeze:  true

    # Create a proc that rotates a list by n positions.
    #
    # @param n [Integer] Number of positions to rotate (default: 1)
    # @return [Proc] A proc that takes a list and returns it rotated
    def rotate(n = 1)
      lambda { |*list| list.rotate(n) }
    end

    alias swap rotate

    # Create a proc that returns its argument unchanged.
    #
    # @return [Proc] A proc that takes an element and returns it unchanged
    def id1
      lambda { |obj| obj }
    end
    memoize function: :id1, freeze:  true

    # Create a proc that returns a constant value.
    #
    # @param konst [Object] The constant value to return (optional)
    # @yield [konst] Block to compute the constant value if not provided
    # @return [Proc] A proc that always returns the same value
    def const(konst = nil, &my_proc)
      konst ||= my_proc.()
      lambda { |*_| konst }
    end

    # Create a proc that returns the nth element of a list.
    #
    # @param n [Integer] The index of the element to return
    # @return [Proc] A proc that takes a list and returns element at index n
    def nth(n)
      lambda { |*list| list[n] }
    end

    # Create a proc that calls a method on self with given arguments.
    #
    # This method uses binding introspection to dynamically determine which
    # method to call, making it useful for creating flexible function
    # references.
    #
    # @yield [] The block that should return a method name (symbol)
    # @return [Proc] A proc that takes arguments and calls the specified method
    # @example Dynamic method invocation
    #   def square(x)
    #     x ** 2
    #   end
    #
    #   proc = Proc.from { :square }
    #   [1, 2, 3].map(&proc)
    #   # => [1, 4, 9]
    def from(&block)
      my_method, binding = block.(), block.binding
      my_self = eval 'self', binding
      lambda { |*list| my_self.__send__(my_method, *list) }
    end
  end
end
