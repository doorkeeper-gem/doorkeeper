module Tins
  # This module provides a way to convert symbols into procs using the
  # __send__ method for dynamic method invocation. It was necessary before
  # Ruby 1.9's built-in Symbol#to_proc functionality. You still can use
  # it for strings, though.
  #
  # Example Usage:
  #   class String
  #     include Tins::ToProc
  #   end
  #
  #   ["hello", "world"].map(&'upcase')  # => ["HELLO", "WORLD"]
  module ToProc
    # Converts a Symbol into a Proc that sends the symbol's name to its
    # argument
    #
    # @return [ Proc ] a Proc that when called will send the symbol's name as a
    # message to obj with args
    def to_proc
      lambda do |obj, *args|
        obj.__send__(self, *args)
      end
    end
  end
end
