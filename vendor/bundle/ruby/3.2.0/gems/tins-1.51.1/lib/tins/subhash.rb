module Tins
  # Tins::Subhash provides methods for creating filtered subsets of hashes
  # based on pattern matching against keys.
  #
  # The subhash method allows you to extract key-value pairs from a hash
  # that match specified patterns, making it easy to work with subsets of
  # hash data based on naming conventions or other criteria.
  #
  # @example Basic usage with string patterns
  #   hash = { 'foo' => 1, 'bar' => 2, 'foobar' => 3 }
  #   sub = hash.subhash('foo')
  #   # => { 'foo' => 1, 'foobar' => 3 }
  #
  # @example Usage with regular expressions
  #   hash = { 'foo' => 1, 'barfoot' => 2, 'foobar' => 3 }
  #   sub = hash.subhash(/^foo/)
  #   # => { 'foo' => 1, 'foobar' => 3 }
  #
  # @example Usage with block for value transformation
  #   hash = { 'foo' => 1, 'bar' => 2, 'foobar' => 3 }
  #   sub = hash.subhash('foo') { |key, value, match_data| value * 2 }
  #   # => { 'foo' => 2, 'foobar' => 6 }
  module Subhash
    # Create a subhash from this hash containing only key-value pairs
    # where the key matches any of the given patterns.
    #
    # Patterns can be:
    # - Regular expressions (matched against key strings)
    # - Strings (exact string matching)
    # - Symbols (converted to strings for matching)
    # - Any object that implements === operator
    #
    # @param patterns [Array<Object>] One or more patterns to match against keys
    # @yield [key, value, match_data] Optional block to transform values
    # @yieldparam key [String] The original hash key
    # @yieldparam value [Object] The original hash value
    # @yieldparam match_data [MatchData, nil] Match data when pattern is regex, nil otherwise
    # @return [Hash] A new hash containing only matching key-value pairs
    def subhash(*patterns)
      patterns.map! do |pat|
        pat = pat.to_sym.to_s if pat.respond_to?(:to_sym)
        pat.respond_to?(:match) ? pat : pat.to_s
      end
      result =
        if default_proc
          self.class.new(&default_proc)
        else
          self.class.new(default)
        end
      if block_given?
        each do |k, v|
          patterns.each { |pat|
            if pat === k.to_s
              result[k] = yield(k, v, $~)
              break
            end
          }
        end
      else
        each do |k, v|
          result[k] = v if patterns.any? { |pat| pat === k.to_s }
        end
      end
      result
    end
  end
end
