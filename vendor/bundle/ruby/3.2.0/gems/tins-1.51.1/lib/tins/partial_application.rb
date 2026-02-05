module Tins
  # A module that provides partial application functionality.
  #
  # This module is designed to be included in classes that respond to `call` and have
  # an `arity` method. It's commonly used with Proc and Method objects, but can be
  # included in any class that implements the required interface.
  #
  # Partial application allows you to create new callables by fixing some arguments
  # of an existing callable, resulting in a callable with fewer parameters.
  #
  # @example Using partial application with Proc
  #   add = proc { |x, y| x + y }
  #   add_five = add.partial(5)           # Fixes first argument to 5
  #   result = add_five.call(3)           # Returns 8 (5 + 3)
  #
  # @example Using partial application with Method
  #   class Calculator
  #     def calculate(x, y, z)
  #       x + y * z
  #     end
  #   end
  #
  #   calc = Calculator.new
  #   method_obj = calc.method(:calculate)
  #   partial_calc = method_obj.partial(1, 2)  # Fixes first two arguments
  #   result = partial_calc.call(3)            # Returns 7 (1 + 2 * 3)
  module PartialApplication
    # Callback invoked when this module is included in a class. Overrides the
    # `arity` method to support custom arity values for partial applications.
    #
    # This is particularly useful for Proc and Method objects where the arity
    # needs to be adjusted after partial application.
    #
    # @param modul [Module] The module that included this module
    def self.included(modul)
      modul.module_eval do
        old_arity = instance_method(:arity)
        define_method(:arity) do
          if defined?(@__arity__)
            @__arity__
          else
            old_arity.bind(self).call
          end
        end
      end
      super
    end

    # Creates a partial application of the current object.
    #
    # If no arguments are provided, returns a duplicate of the current object.
    # If more arguments are provided than the object's arity, raises an
    # ArgumentError. Otherwise, creates a new lambda that combines the provided
    # arguments with additional arguments when called.
    #
    # This method is particularly useful for creating curried functions or
    # partially applied methods where some parameters are pre-filled.
    #
    # @param args [Array] Arguments to partially apply to the callable
    # @return [Proc] A partial application of this object with adjusted arity
    # @raise [ArgumentError] If too many arguments are provided for the arity
    # @example
    #   add = proc { |x, y| x + y }
    #   add_five = add.partial(5)
    #   add_five.call(3)  # => 8
    #
    # @example With Method objects
    #   class MathOps
    #     def multiply(a, b, c)
    #       a * b * c
    #     end
    #   end
    #
    #   ops = MathOps.new
    #   method_obj = ops.method(:multiply)
    #   partial_mult = method_obj.partial(2, 3)
    #   partial_mult.call(4)  # => 24 (2 * 3 * 4)
    def partial(*args)
      if args.empty?
        dup
      elsif args.size > arity
        raise ArgumentError, "wrong number of arguments (#{args.size} for #{arity})"
      else
        f = lambda { |*b| call(*(args + b)) }
        f.instance_variable_set :@__arity__, arity - args.size
        f
      end
    end
  end
end
