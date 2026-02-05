module Tins
  # Provides methods for defining abstract method implementations that raise
  # NotImplementedError. Useful for creating interface-like modules or base
  # classes where certain methods must be implemented by subclasses.
  #
  # @example Basic usage
  #   module MyInterface
  #     include Tins::Implement
  #     implement :process
  #   end
  #
  #   class MyClass
  #     include MyInterface
  #     # Must implement process method or it will raise NotImplementedError
  #   end
  #
  # @example With custom messages
  #   module ApiInterface
  #     include Tins::Implement
  #     implement :get_data, :subclass
  #     implement :post_data, :submodule
  #   end
  #
  # @see Tins::MethodDescription For method description integration
  module Implement
    # Predefined error message templates for different implementation contexts.
    #
    # These templates provide context-specific error messages that help
    # developers understand where and how methods should be implemented.
    MESSAGES = {
      default:   'method %{method_name} not implemented in module %{module}',
      subclass:  'method %{method_name} has to be implemented in '\
        'subclasses of %{module}',
      submodule: 'method %{method_name} has to be implemented in '\
        'submodules of %{module}',
    }

    # Defines an implementation for a method that raises NotImplementedError.
    #
    # @param method_name [Symbol, String] The name of the method to implement
    # @param msg [Symbol, String, Hash] The error message template or options
    #   @option msg [Symbol] :in When msg is a Hash, specifies which message key to use
    #
    # @example Basic usage
    #   implement :process
    #   # => Defines process method that raises NotImplementedError
    #
    # @example Custom message
    #   implement :calculate, 'Custom error message'
    #
    # @example Using predefined message template
    #   implement :validate, :subclass
    def implement(method_name, msg = :default)
      method_name.nil? and return
      case msg
      when ::Symbol
        msg = MESSAGES.fetch(msg)
      when ::Hash
        return implement method_name, msg.fetch(:in)
      end
      display_method_name = method_name
      if m = instance_method(method_name) rescue nil
        m.extend Tins::MethodDescription
        display_method_name = m.description(style: :name)
      end
      begin
        msg = msg % { method_name: display_method_name, module: self }
      rescue KeyError
      end
      define_method(method_name) do |*|
        raise ::NotImplementedError, msg
      end
    end

    # Defines an implementation for a method that raises NotImplementedError
    # specifically for submodule implementations.
    #
    # @param method_name [Symbol, String] The name of the method to implement
    #
    # @example Usage
    #   implement_in_submodule :render
    #   # => Defines render method with submodule-specific error message
    def implement_in_submodule(method_name)
      implement method_name,
        'method %{method_name} has to be implemented in submodules of'\
        ' %{module}'
    end
  end
end

