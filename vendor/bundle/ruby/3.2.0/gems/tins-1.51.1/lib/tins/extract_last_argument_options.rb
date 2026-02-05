module Tins
  # Extracts the last argument from an array if it responds to to_hash
  #
  # This module provides a method to separate arguments into regular arguments
  # and options (a hash) by checking if the last element responds to to_hash
  module ExtractLastArgumentOptions
    # Extracts the last argument if it responds to to_hash and returns an array
    # with the remaining elements and the extracted options hash.
    #
    # @return [Array<Object, Hash>] an array containing the sliced array and
    # the extracted options hash
    def extract_last_argument_options
      last_argument = last
      if last_argument.respond_to?(:to_hash) and
        options = last_argument.to_hash.dup
      then
        return self[0..-2], options
      else
        return dup, {}
      end
    end
  end
end
