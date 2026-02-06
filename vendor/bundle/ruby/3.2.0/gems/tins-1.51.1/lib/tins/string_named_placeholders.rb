module Tins
  # A module that provides methods for working with named placeholders in strings.
  #
  # This module adds functionality to extract named placeholders from strings
  # and assign values to them, making it easier to work with template-style
  # strings that contain named substitution points.
  #
  # @example Extracting named placeholders from a string
  #   "Hello %{name}, you have %{count} messages".named_placeholders
  #   # => [:name, :count]
  #
  # @example Assigning values to named placeholders
  #   template = "Welcome %{user}, your balance is %{amount}"
  #   template.named_placeholders_assign(user: "Alice", amount: "$100")
  #   # => {:user=>"Alice", :amount=>"$100"}
  module StringNamedPlaceholders
    # Returns an array of symbols representing the named placeholders found in
    # the string.
    #
    # This method scans the string for patterns matching named placeholders in
    # the format %{name} and extracts the placeholder names, returning them as
    # symbols in an array.
    #
    # @return [Array<Symbol>] An array of unique symbol representations of the
    # named placeholders found in the string.
    def named_placeholders
      scan(/%\{([^}]+)\}/).inject([], &:concat).uniq.map(&:to_sym)
    end

    # Assign values to named placeholders from a hash, using a default value
    # for unspecified placeholders.
    #
    # This method takes a hash of placeholder values and assigns them to the
    # named placeholders found in the string. If a placeholder is not present
    # in the input hash, the provided default value is used instead. The
    # default can be a static value or a proc that receives the placeholder
    # symbol as an argument.
    #
    # @param hash [Hash] A hash mapping placeholder names to their corresponding values.
    # @param default [Object, Proc] The default value to use for placeholders not present in the hash.
    #                              If a proc is provided, it will be called with the placeholder symbol.
    #
    # @return [Hash] A new hash containing the assigned values for each named
    # placeholder.
    def named_placeholders_assign(hash, default: nil)
      hash = hash.transform_keys(&:to_sym)
      named_placeholders.each_with_object({}) do |placeholder, h|
        h[placeholder] = hash[placeholder] ||
          (default.is_a?(Proc) ? default.(placeholder) : default)
      end
    end

    # Interpolate named placeholders in the string with values from a hash.
    #
    # This method takes a hash of placeholder values and substitutes the named
    # placeholders found in the string with their corresponding values.
    # Placeholders that are not present in the input hash will be replaced with
    # the provided default value.
    #
    # @param hash [Hash] A hash mapping placeholder names to their corresponding values
    # @param default [Object, Proc] The default value to use for placeholders not present in the hash
    #                              If a proc is provided, it will be called with the placeholder symbol
    #
    # @return [String] A new string with named placeholders replaced by their values
    def named_placeholders_interpolate(hash, default: nil)
      values = named_placeholders_assign(hash, default:)
      self % values
    end
  end
end
