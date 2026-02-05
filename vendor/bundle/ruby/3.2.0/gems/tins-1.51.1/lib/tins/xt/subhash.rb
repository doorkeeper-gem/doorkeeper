require 'tins/subhash'

module Tins
  class ::Hash
    include Tins::Subhash

    # The subhash! method creates a filtered subset of this hash based on the
    # given patterns and replaces the current hash with the result.
    #
    # This method works by first calling subhash with the provided patterns to
    # create a new hash containing only the matching key-value pairs, then
    # replacing the contents of the current hash with those pairs.
    #
    # @param patterns [Array<Object>] One or more patterns to match against
    # keys
    # @return [Hash] Returns self after replacing its contents with the
    # filtered subset
    def subhash!(*patterns)
      replace subhash(*patterns)
    end
  end
end
