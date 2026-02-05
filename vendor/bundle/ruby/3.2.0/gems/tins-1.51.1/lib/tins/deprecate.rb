module Tins
  # A module for deprecating methods with customizable messages and warnings.
  #
  # @example
  #   class MyClass
  #     extend Tins::Deprecate
  #     deprecate method: :old_method, new_method: :new_method
  #   end
  module Deprecate
    # Deprecates a method and issues a warning when called.
    #
    # @param method [ Symbol ] the name of the method to deprecate
    # @param new_method [ Symbol ] the name of the replacement method
    # @param message [ String ] the warning message to display
    def deprecate(method:, new_method: nil, message: nil)
      message ||= '[DEPRECATION] `%{method}` is deprecated. Please use `%{new_method}` instead.'
      message = message % { method: method, new_method: new_method }
      m = Module.new do
        define_method(method) do |*a, **kw, &b|
          warn message
          super(*a, **kw, &b)
        end
      end
      prepend m
    end
  end
end
