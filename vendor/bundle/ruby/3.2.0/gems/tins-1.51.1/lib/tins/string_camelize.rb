module Tins
  # Tins::StringCamelize provides methods for converting snake_case strings
  # to camelCase or PascalCase format.
  #
  # This module contains the `camelize` method which is commonly used in Ruby
  # applications, particularly in Rails-style naming conventions where developers
  # need to convert between different naming styles.
  #
  # @example Converting snake_case to PascalCase (default)
  #   "snake_case_string".camelize
  #   # => "SnakeCaseString"
  #
  # @example Converting snake_case to camelCase
  #   "snake_case_string".camelize(:lower)
  #   # => "snakeCaseString"
  #
  # @example Handling nested module paths
  #   "my/module/class_name".camelize
  #   # => "My::Module::ClassName"
  module StringCamelize
    # Convert a snake_case string to camelCase or PascalCase format.
    #
    # This method handles various naming conventions:
    # - Converts snake_case to PascalCase (default) or camelCase
    # - Handles nested module paths with '/' separators
    # - Supports different first letter cases
    #
    # @param first_letter [Symbol, Boolean] Controls capitalization of first letter
    # @option first_letter :upper (default) Convert first letter to uppercase (PascalCase)
    # @option first_letter :lower Convert first letter to lowercase (camelCase)
    # @option first_letter true Same as :upper
    # @option first_letter false Same as :lower
    # @return [String] A new string in camelCase or PascalCase format
    def camelize(first_letter = :upper)
      case first_letter
      when :upper, true
        gsub(/\/(.?)/) { "::#{$1.upcase}" }.gsub(/(?:^|_)(.)/) { $1.upcase }
      when :lower, false
        self[0].chr.downcase + camelize[1..-1]
      end
    end

    alias camelcase camelize
  end
end
