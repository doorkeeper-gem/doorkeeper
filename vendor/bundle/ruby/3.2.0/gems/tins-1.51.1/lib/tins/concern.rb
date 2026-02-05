module Tins
  # A module concern implementation that supports dependency tracking, class
  # method inclusion, and block execution hooks.
  #
  # This module provides a way to define reusable module functionality with
  # automatic dependency management, class method injection, and lifecycle
  # callbacks similar to ActiveSupport::Concern but with more control.
  #
  # @example Basic usage
  #   module MyConcern
  #     extend Tins::Concern
  #
  #     included do
  #       attr_accessor :logger
  #     end
  #
  #     def log(message)
  #       logger&.info message
  #     end
  #
  #     class_methods do
  #       def my_class_method
  #         # ...
  #       end
  #     end
  #   end
  #
  #   class MyClass
  #     include MyConcern
  #   end
  module Concern
    # Extends the base object with dependency tracking capabilities.
    #
    # This method initializes an instance variable on the base object to store
    # dependency information.
    #
    # @param base [ Object ] the object being extended
    def self.extended(base)
      base.instance_variable_set("@_dependencies", [])
    end

    # The append_features method includes dependencies and class methods in the
    # base class.
    #
    # @param base [ Object ] the base class to include features in
    # @return [ Boolean ] true if features were appended, false otherwise
    def append_features(base)
      if base.instance_variable_defined?("@_dependencies")
        base.instance_variable_get("@_dependencies") << self
        false
      else
        return false if base < self
        @_dependencies.each { |dep| base.send(:include, dep) }
        super
        base.extend const_get("ClassMethods") if const_defined?("ClassMethods")
        base.class_eval(&@_included_block) if instance_variable_defined?("@_included_block")
        Thread.current[:tin_concern_args] = nil
        true
      end
    end

    # Prepends the features of this module to the base class.
    #
    # This method handles the inclusion of dependencies and class methods when
    # a module is included in a class. It manages dependency tracking and
    # ensures proper extension of the base class with ClassMethods.
    #
    # @param base [Class] the class that includes this module
    # @return [Boolean] true if the module was successfully prepended, false otherwise
    def prepend_features(base)
      if base.instance_variable_defined?("@_dependencies")
        base.instance_variable_get("@_dependencies") << self
        false
      else
        return false if base < self
        @_dependencies.each { |dep| base.send(:include, dep) }
        super
        base.extend const_get("ClassMethods") if const_defined?("ClassMethods")
        base.class_eval(&@_prepended_block) if instance_variable_defined?("@_prepended_block")
        Thread.current[:tin_concern_args] = nil
        true
      end
    end

    # The included method is called when the module is included in a class or
    # module.
    #
    # @param base [ Object ] the class or module that includes this module
    # @param block [ Proc ] optional block to be executed when included
    def included(base = nil, &block)
      if base.nil?
        instance_variable_defined?(:@_included_block) and
          raise StandardError, "included block already defined"
        @_included_block = block
      else
        super
      end
    end

    # The prepended method handles the setup of a block for prepend
    # functionality or delegates to the superclass implementation
    #
    # @param base [ Object ] the base object to prepend to, or nil to set up a block
    # @param block [ Proc ] the block to be used for prepend functionality
    def prepended(base = nil, &block)
      if base.nil?
        instance_variable_defined?(:@_prepended_block) and
          raise StandardError, "prepended block already defined"
        @_prepended_block = block
      else
        super
      end
    end

    # Defines a ClassMethods module for the current class and evaluates the
    # given block within it.
    #
    # @param block [Proc] The block to be evaluated in the context of the
    # ClassMethods module
    # @return [Module] The ClassMethods module that was defined or retrieved
    def class_methods(&block)
      modul = const_get(:ClassMethods) if const_defined?(:ClassMethods, false)
      unless modul
        modul = Module.new
        const_set(:ClassMethods, modul)
      end
      modul.module_eval(&block)
    end
  end
end
