module Tins
  # A module that provides a way to expose private and protected methods for
  # testing or debugging purposes.
  #
  # This module is particularly useful in test suites where you need to verify
  # internal implementation details without making methods public, or for
  # debugging complex object states during development.
  #
  # @example Basic method exposure
  #   obj = MyClass.new
  #   exposed_obj = obj.expose
  #   exposed_obj.private_method  # Accessible now
  #
  # @example Direct method call
  #   obj = MyClass.new
  #   result = obj.expose(:private_method)
  #   # Equivalent to: obj.private_method
  #
  # @example Block execution
  #   obj = MyClass.new
  #   obj.expose { self.private_method }
  #
  # @example Testing private methods
  #   describe MyClass do
  #     it "should handle edge cases" do
  #       obj = MyClass.new
  #       result = obj.expose(:private_calculation, arg1, arg2)
  #       expect(result).to eq(expected_value)
  #     end
  #   end
  #
  # @note This module should only be used in test or debugging contexts.
  #       Using it in production code can compromise encapsulation.
  # @note Modifying the exposed object's state may affect the original object
  #          since it operates on a duplicated instance.
  module Expose
    # Expose any (private/protected) method or internal state of this object
    # returning the result for specing purposes.
    #
    # This method provides three distinct usage patterns:
    #
    # 1. **Method Call**: When given a method name, directly calls that method
    #    and returns its result.
    #
    # 2. **Block Execution**: When given a block, evaluates the block in the
    #    context of the object, allowing access to private/protected methods.
    #
    # 3. **Full Exposure**: When called without arguments, returns a duplicate
    #    of the object with all private and protected methods exposed as public.
    #
    # @param method_name [Symbol, String, nil] name of the method to call,
    #                                          or nil for full exposure
    # @param args [Array] arguments to pass to the method when calling it
    # @param block [Proc] block to execute in the context of the object
    #
    # @return [Object] result of the method call, block execution, or a new
    #                  object with exposed methods (when called without args)
    #
    # @raise [NoMethodError] if method_name is given but doesn't exist
    # @raise [ArgumentError] if both method_name and block are provided
    def expose(method_name = nil, *args, &block)
      if block
        instance_eval(&block)
      elsif method_name.nil?
        methods = private_methods(true) + protected_methods(true)
        o = dup
        o.singleton_class.class_eval do
          public(*methods)
        end
        o
      elsif method_name
        __send__(method_name, *args)
      end
    end
  end
end
