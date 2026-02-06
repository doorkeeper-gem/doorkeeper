module Tins
  # Tins::Null provides an implementation of the null object pattern in Ruby.
  #
  # The null object pattern is a behavioral design pattern that allows you to
  # avoid null references by providing a default object that implements the
  # expected interface but does nothing. This eliminates the need for null
  # checks throughout your codebase.
  #
  # This module provides the core functionality for null objects, including:
  # - Method missing behavior that returns self
  # - Type conversion methods that return appropriate default values
  # - Debugging support through NullPlus
  #
  # @example Basic usage
  #   # Instead of checking for nil:
  #   user = find_user(id)
  #   if user
  #     user.name
  #   else
  #     "Unknown"
  #   end
  #
  #   # You can use the null object:
  #   user = find_user(id) || Tins::NULL
  #   user.name  # => "" (instead of nil)
  #
  # @example With NullPlus for debugging
  #   user = find_user(id) || Tins::NullPlus.new(value: "Unknown", caller: caller)
  #   user.value  # => "Unknown"
  module Null
    # Handle missing methods by returning self, allowing method chaining.
    #
    # @return [self] Always returns self to allow chaining
    def method_missing(*)
      self
    end

    # Handle missing constants by returning self.
    #
    # @return [self] Always returns self
    def const_missing(*)
      self
    end

    # Convert to string representation.
    #
    # @return [String] Empty string
    def to_s
      ''
    end

    # Convert to float.
    #
    # @return [Float] Zero as float
    def to_f
      0.0
    end

    # Convert to integer.
    #
    # @return [Integer] Zero
    def to_i
      0
    end

    # Convert to array.
    #
    # @return [Array] Empty array
    def to_a
      []
    end

    # Inspect representation.
    #
    # @return [String] "NULL"
    def inspect
      'NULL'
    end

    # Check if object is nil.
    #
    # @return [Boolean] Always returns true
    def nil?
      true
    end

    # Check if object is blank.
    #
    # @return [Boolean] Always returns true
    def blank?
      true
    end

    # Convert to JSON (for compatibility with JSON serialization).
    #
    # @return [nil] returns nil value
    def as_json(*)
      nil
    end

    # Convert to JSON string.
    #
    # @return [String] "null"
    def to_json(*)
      'null'
    end

    # Kernel extensions for null object creation.
    module Kernel
      # Create a null object or return the provided value if not nil.
      #
      # @param value [Object] The value to check
      # @return [Object] Tins::NULL if value is nil, otherwise value
      def null(value = nil)
        value.nil? ? Tins::NULL : value
      end

      alias Null null

      # Create a null object with additional debugging information.
      #
      # This creates a NullPlus object that includes caller information for
      # debugging purposes when the null object is used.
      #
      # @param opts [Hash] Options for the null object
      # @option opts [Object] :value The value to return from the null object
      # @option opts [Array] :caller Caller information
      # @return [Object] Tins::NullPlus if value is nil, otherwise value
      def null_plus(opts = {})
        value = opts[:value]
        opts[:caller] = caller
        if respond_to?(:caller_locations, true)
          opts[:caller_locations] = caller_locations
        end

        value.nil? ? Tins::NullPlus.new(opts) : value
      end

      alias NullPlus null_plus
    end
  end

  # NullClass represents the singleton null object instance.
  class NullClass < Module
    include Tins::Null
  end

  # The singleton null object instance.
  NULL = NullClass.new

  # Freeze the singleton to prevent modification.
  NULL.freeze

  # Enhanced null object with debugging capabilities.
  #
  # NullPlus extends the basic null object with additional features for debugging,
  # including caller information and custom attribute access.
  class NullPlus
    include Tins::Null

    # Initialize a NullPlus object with options.
    #
    # @param opts [Hash] Configuration options
    def initialize(opts = {})
      singleton_class.class_eval do
        opts.each do |name, value|
          define_method(name) { value }
        end
      end
    end
  end
end
