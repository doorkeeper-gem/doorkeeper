module Tins
  # Provides methods for describing method signatures and parameters.
  #
  # This module is designed to be included in method objects to provide
  # introspection capabilities, particularly useful for generating
  # documentation or debugging method signatures.
  module MethodDescription
    # Represents individual parameters with specific types and names.
    class Parameters
      # Base class for all parameter types.
      class Parameter < Struct.new(:type, :name)
        # Compares two parameters by their type.
        #
        # @param other [Parameter] The other parameter to compare against
        # @return [Boolean] Whether the types are equal
        def ==(other)
          type == other.type
        end

        # Returns a string representation of the parameter for debugging.
        #
        # @return [String] A debug-friendly representation
        def inspect
          "#<#{self.class} #{to_s.inspect}>"
        end
      end

      # Represents a splat parameter (*args).
      class RestParameter < Parameter
        # Converts the parameter to its string form.
        #
        # @return [String] Formatted as "*name"
        def to_s
          "*#{name}"
        end
      end

      # Represents a keyword rest parameter (**kwargs).
      class KeyrestParameter < Parameter
        # Converts the parameter to its string form.
        #
        # @return [String] Formatted as "**name"
        def to_s
          "**#{name}"
        end
      end

      # Represents a required parameter.
      class ReqParameter < Parameter
        # Converts the parameter to its string form.
        #
        # @return [String] The parameter name
        def to_s
          name.to_s
        end
      end

      # Represents an optional parameter (with default value).
      class OptParameter < Parameter
        # Converts the parameter to its string form.
        #
        # @return [String] Formatted as "name=..."
        def to_s
          "#{name}=…"
        end
      end

      # Represents a keyword parameter.
      class KeyParameter < Parameter
        # Converts the parameter to its string form.
        #
        # @return [String] Formatted as "name:..."
        def to_s
          "#{name}:…"
        end
      end

      # Represents a required keyword parameter (without default).
      class KeyreqParameter < Parameter
        # Converts the parameter to its string form.
        #
        # @return [String] Formatted as "name:"
        def to_s
          "#{name}:"
        end
      end

      # Represents a block parameter (&block).
      class BlockParameter < Parameter
        # Converts the parameter to its string form.
        #
        # @return [String] Formatted as "&name"
        def to_s
          "&#{name}"
        end
      end

      # Represents a generic parameter type not covered by other classes.
      class GenericParameter < Parameter
        # Converts the parameter to its string form.
        #
        # @return [String] Formatted as "name:type"
        def to_s
          [ name, type ] * ?:
        end
      end

      # Builds a parameter instance based on type and name.
      #
      # @param type [Symbol] The type of parameter (e.g., :req, :opt)
      # @param name [String, Symbol] The parameter name
      # @return [Parameter] An appropriate Parameter subclass or GenericParameter
      def self.build(type, name)
        parameter_classname = "#{type.to_s.capitalize}Parameter"
        parameter_class =
          if const_defined? parameter_classname
            const_get parameter_classname
          else
            GenericParameter
          end
        parameter_class.new(type, name)
      end
    end

    # Represents the signature of a method including all its parameters.
    class Signature
      # Initializes a new signature with given parameters.
      #
      # @param parameters [Array<Parameters::Parameter>] The list of parameters
      def initialize(*parameters)
        @parameters = parameters
      end

      # Returns the parameters associated with this signature.
      #
      # @return [Array<Parameters::Parameter>] The method's parameters
      attr_reader :parameters

      # Checks if two signatures are equal based on their parameters.
      #
      # @param other [Signature] The other signature to compare against
      # @return [Boolean] Whether the signatures are equal
      def eql?(other)
        @parameters.eql? other.parameters
      end

      # Checks if two signatures are equal (alias for eql?).
      #
      # @param other [Signature] The other signature to compare against
      # @return [Boolean] Whether the signatures are equal
      def ==(other)
        @parameters == other.parameters
      end

      # Pattern matching operator for comparing with a method's signature.
      #
      # @param method [Method] The method whose signature we're checking
      # @return [Boolean] Whether this signature matches the method's signature
      def ===(method)
        self == method.signature
      end

      # Converts the signature to a comma-separated string.
      #
      # @return [String] The parameters formatted as a string
      def to_s
        @parameters * ?,
      end

      # Returns a detailed string representation for debugging.
      #
      # @return [String] A debug-friendly representation of the signature
      def inspect
        "#<#{self.class} (#{to_s})>"
      end
    end

    # Retrieves the signature of the method this module is included in.
    #
    # @return [Signature] The method's signature
    def signature
      description style: :parameters
    end

    # Generates a human-readable description of the method.
    #
    # @param style [:namespace, :name, :parameters] The output format style
    # @return [String, Signature] The formatted description or signature object
    def description(style: :namespace)
      valid_styles = %i[ namespace name parameters ]
      valid_styles.include?(style) or
        raise ArgumentError,
        "style has to be one of #{valid_styles * ', '}"
      if respond_to?(:parameters)
        generated_name = 'x0'
        parameter_array = parameters.map { |p_type, p_name|
          unless p_name
            generated_name = generated_name.succ
            p_name = generated_name
          end
          Parameters.build(p_type, p_name)
        }
        signature = Signature.new(*parameter_array)
        if style == :parameters
          return signature
        end
      end
      result = +''
      if style == :namespace
        if owner <= Module
          result << receiver.to_s << ?.
        else
          result << owner.name.to_s << ?#
        end
      end
      if %i[ namespace name ].include?(style)
        result << name.to_s << '('
      end
      result << (signature || arity).to_s
      if %i[ namespace name ].include?(style)
        result << ?)
      end
      result
    end
  end
end
