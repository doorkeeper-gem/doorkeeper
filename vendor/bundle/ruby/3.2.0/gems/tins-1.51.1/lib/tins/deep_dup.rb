module Tins
  # DeepDup module provides a method to deeply duplicate objects in Ruby.
  #
  # This module extends the Object class with a deep_dup method that creates a
  # recursive copy of an object and all its nested objects.
  module DeepDup
    # Duplicates an object deeply by marshaling and unmarshaling it. For
    # objects that can't be marshaled, it returns the object itself.
    #
    # @return [Object] a deep duplicate of the object or the object itself if
    # it can't be marshaled
    def deep_dup
      Marshal.load(Marshal.dump(self))
    rescue TypeError
      return self
    end
  end
end
