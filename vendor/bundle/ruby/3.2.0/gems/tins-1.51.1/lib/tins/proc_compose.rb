module Tins
  # A module that provides function composition functionality for Proc objects.
  #
  # This module enables the composition of two functions (procs) such that the
  # result is a new proc that applies the second function to the input, then
  # applies the first function to the result. This follows the mathematical
  # concept of function composition: (f ∘ g)(x) = f(g(x))
  #
  # @example Basic composition
  #   add_one = proc { |x| x + 1 }
  #   multiply_by_two = proc { |x| x * 2 }
  #
  #   composed = multiply_by_two.compose(add_one)
  #   composed.call(5)  # => 12 (2 * (5 + 1))
  #
  # @example Using the alias operator
  #   add_one = proc { |x| x + 1 }
  #   multiply_by_two = proc { |x| x * 2 }
  #
  #   composed = multiply_by_two * add_one
  #   composed.call(5)  # => 12
  module ProcCompose
    # Composes this proc with another callable, creating a new proc that
    # applies the other callable first, then applies this proc to its result.
    #
    # The composition follows the mathematical convention:
    #
    # (self ∘ other)(args) = self(other(args))
    #
    # @param other [Proc, Method, Object] A callable object that responds to `call`
    #   or can be converted to a proc via `to_proc`
    # @return [Proc] A new proc representing the composition
    # @example
    #   square = proc { |x| x * x }
    #   add_one = proc { |x| x + 1 }
    #
    #   composed = square.compose(add_one)
    #   composed.call(3)  # => 16 ((3 + 1)²)
    #
    # @example With Method objects
    #   class MathOps
    #     def square(x)
    #       x * x
    #     end
    #   end
    #
    #   math = MathOps.new
    #   add_one = proc { |x| x + 1 }
    #   composed = math.method(:square).compose(add_one)
    #   composed.call(3)  # => 16 ((3 + 1)²)
    def compose(other)
      block = -> *args {
        if other.respond_to?(:call)
          call(*other.call(*args))
        else
          call(*other.to_proc.call(*args))
        end
      }
      if self.class.respond_to?(:new)
        self.class.new(&block)
      else
        Proc.new(&block)
      end
    end

    # Alias for {compose} method, enabling the use of the * operator for
    # composition.
    #
    # @see compose
    alias * compose
  end
end
