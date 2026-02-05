module Tins
  # Tins::StringUnderscore provides methods for converting camelCase and
  # PascalCase strings to snake_case format.
  #
  # This module contains the `underscore` method which is commonly used in Ruby
  # applications, particularly in Rails-style naming conventions where developers
  # need to convert between different naming styles.
  #
  # @example Converting camelCase to snake_case
  #   "camelCaseString".underscore
  #   # => "camel_case_string"
  #
  # @example Converting PascalCase to snake_case
  #   "PascalCaseString".underscore
  #   # => "pascal_case_string"
  #
  # @example Handling nested modules
  #   "My::Module::ClassName".underscore
  #   # => "my/module/class_name"
  #
  # @example Mixed case with dashes
  #   "camel-case-string".underscore
  #   # => "camel_case_string"
  module StringUnderscore
    # Convert a camelCase or PascalCase string to snake_case format.
    #
    # This method handles various naming conventions:
    # - Converts camelCase to snake_case (e.g., "camelCase" → "camel_case")
    # - Converts PascalCase to snake_case (e.g., "PascalCase" → "pascal_case")
    # - Handles consecutive uppercase letters (e.g., "XMLParser" → "xml_parser")
    # - Replaces dashes with underscores
    # - Converts to lowercase
    # - Handles nested module paths with '::' separators
    #
    # @return [String] A new string in snake_case format
    def underscore
      word = dup
      word.gsub!(/::/, '/')
      word.gsub!(/([A-Z]+)([A-Z][a-z])/,'\1_\2')
      word.gsub!(/([a-z\d])([A-Z])/,'\1_\2')
      word.tr!("-", "_")
      word.downcase!
      word
    end
  end
end
