require 'tins/xt/blank'

module Tins
  # Provides methods for checking if objects are "full" (non-blank) and safely
  # processing them in conditional contexts.
  #
  # This module adds the `full?` and `all_full?` methods to all objects, enabling
  # clean, readable patterns for validation and conditional processing.
  #
  # @example Basic usage
  #   "hello".full?        # => "hello"
  #   "".full?             # => nil
  #
  # @example Method dispatch with block
  #   user.full?(:name) { |name| "Hello #{name}" }  # Returns "Hello John" if name is full
  #
  # @example Safe assignment and processing
  #   if name = user.full?(:name)
  #     puts "Hello #{name}"
  #   end
  module Full
    # Checks if the object is not blank, returning the object itself if it's
    # full, or nil if it's blank. If a method name is provided as +dispatch+,
    # that method is called on the object and the result is checked for being
    # full.
    #
    # @param dispatch [Symbol, nil] The method to call on the object (optional)
    # @param args [Array] Arguments to pass to the dispatched method (optional)
    # @yield [Object] Optional block to execute with the result if result or
    # dispatched result not nil
    # @return [Object, nil] The object itself if not blank, or the result of
    #   dispatching +dispatch+ if provided and valid, or nil if the object is blank
    #
    # @example Basic usage
    #   "hello".full?        # => "hello"
    #   "".full?             # => nil
    #
    # @example Method dispatch
    #   user.full?(:name)    # Returns user.name if not blank, nil otherwise
    #
    # @example Method dispatch with arguments
    #   user.full?(:method_with_args, arg1, arg2)
    #
    # @example With block execution
    #   user.full?(:name) { |name| "Hello #{name}" }
    def full?(dispatch = nil, *args)
      if blank?
        obj = nil
      elsif dispatch
        obj = __send__(dispatch, *args)
        obj = nil if obj.blank?
      else
        obj = self
      end
      if block_given? and obj
        yield obj
      else
        obj
      end
    end

    # Checks if all elements in a collection are "full" (not blank). If the
    # object responds to +all?+ and all elements pass the +full?+ test, then
    # the block is executed with the collection itself or the collection is returned.
    #
    # @return [Object, nil] The collection if all elements are full, otherwise nil
    #
    # @example Basic usage
    #   [1,2,3].all_full?    # => [1,2,3]
    #   [1,nil,3].all_full?  # => nil
    #
    # @example With block execution
    #   [1,2,3].all_full? { |array| array.sum }
    def all_full?
      if respond_to?(:all?) && all?(&:full?)
        block_given? ? yield(self) : self
      end
    end

    class ::Object
      include Full
    end
  end
end
