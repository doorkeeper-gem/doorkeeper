require 'tins/extract_last_argument_options'
require 'mize'

module Tins
  # Provides memoization functionality for methods and functions with support
  # for instance-level and class-level caching respectively.
  #
  # @example Basic method memoization
  #   class Calculator
  #     def expensive_calculation(x, y)
  #       # Some expensive computation
  #       x * y
  #     end
  #     memoize_method :expensive_calculation
  #   end
  #
  # @example Function memoization (shared across instances)
  #   class MathUtils
  #     def self.factorial(n)
  #       n <= 1 ? 1 : n * factorial(n - 1)
  #     end
  #     memoize_function :factorial
  #   end
  #
  # @example With freezing results
  #   class DataProcessor
  #     def process_data(input)
  #       # Process data and return result
  #       input.dup
  #     end
  #     memoize_method :process_data, freeze: true
  #   end
  #
  # @note This module is deprecated in favor of the {https://github.com/flori/mize mize} gem.
  #       Use `memoize method:` or `memoize function:` from the mize gem directly.
  module Memoize
    # Provides cache management methods for memoized functions and methods.
    # This module is included in classes that use memoization functionality.
    #
    # @example Using cache methods directly
    #   class Example
    #     include Tins::Memoize::CacheMethods
    #
    #     def expensive_method
    #       # Some expensive computation
    #     end
    #     memoize_method :expensive_method
    #   end
    #
    #   obj = Example.new
    #   obj.memoize_cache_clear  # Clear all cached values
    #   obj.__memoize_cache__    # Access the internal cache object
    module CacheMethods
      # Return the cache object used for memoization.
      #
      # @return [Object] The cache instance
      def __memoize_cache__
        if @__memoize_cache__
          @__memoize_cache__
        else
          @__memoize_cache__ = __mize_cache__
          def @__memoize_cache__.empty?
            @data.empty?
          end
          @__memoize_cache__
        end
      end

      # Clear cached values for all methods/functions of this object.
      #
      # @return [self] For chaining
      def memoize_cache_clear
         __memoize_cache__.clear
        self
      end
    end

    class ::Module
      # Memoize a method so that its return value is cached based on the arguments
      # and the object instance. Each instance maintains its own cache.
      #
      # @param method_ids [Array<Symbol>] One or more method names to memoize
      # @option opts [Boolean] :freeze (false) Whether to freeze results
      # @return [Symbol, Array<Symbol>] The memoized method name(s)
      #
      # @deprecated Use `memoize method:` from the mize gem instead.
      def memoize_method(*method_ids)
        warn "[DEPRECATION] `memoize_method` is deprecated. Please use `memoize method:` from mize gem."
        method_ids.extend(ExtractLastArgumentOptions)
        method_ids, opts = method_ids.extract_last_argument_options
        method_ids.each do |method|
          memoize method:, **opts.slice(:freeze)
        end
        include CacheMethods
        method_ids.size == 1 ? method_ids.first : method_ids
      end

      include CacheMethods

      # Memoize a function (class method) so that its return value is cached
      # based only on the arguments, shared across all instances of the class.
      #
      # @param function_ids [Array<Symbol>] One or more function names to memoize
      # @option opts [Boolean] :freeze (false) Whether to freeze results
      # @return [Symbol, Array<Symbol>] The memoized function name(s)
      #
      # @deprecated Use `memoize function:` from the mize gem instead.
      def memoize_function(*function_ids)
        warn "[DEPRECATION] `memoize_function` is deprecated. Please use `memoize function:` from mize gem."
        function_ids.extend(ExtractLastArgumentOptions)
        function_ids, opts = function_ids.extract_last_argument_options
        function_ids.each do |function|
          memoize function:, **opts.slice(:freeze)
        end
        function_ids.size == 1 ? function_ids.first : function_ids
      end
    end
  end
end
