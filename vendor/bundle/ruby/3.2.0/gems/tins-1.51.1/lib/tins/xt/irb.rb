require 'irb'

# Provides interactive debugging capabilities through the IRB console.
#
# This module adds an `examine` method to all objects, allowing developers to
# quickly drop into an interactive IRB session with the current binding or
# examine specific objects. It's particularly useful for debugging and exploring
# data structures during development.
#
# @example Basic usage
#   # Drop into IRB with current context
#   examine
#
# @example Examine a specific object
#   data = [1, 2, 3]
#   examine data  # Inspects just the 'data' variable
#
# @example Use from within methods
#   def process_data
#     result = expensive_operation
#     examine result  # Debug the result immediately
#   end
module Tins
  # We have our own IRB as well.
  IRB = ::IRB

  # We extend the top level IRB module
  module ::IRB
    # Starts an interactive IRB session with the given binding context. This
    # method creates a new IRB instance and evaluates input from it, allowing for
    # interactive exploration of variables and objects.
    #
    # @param binding [Binding, nil] The binding context to examine (defaults to TOPLEVEL_BINDING)
    #
    # @example Start IRB with current context
    #   examine
    #
    # @example Examine specific binding
    #   examine some_binding
    def self.examine(binding = TOPLEVEL_BINDING)
      setup nil
      workspace = WorkSpace.new binding
      irb = Irb.new workspace
      @CONF[:MAIN_CONTEXT] = irb.context
      catch(:IRB_EXIT) { irb.eval_input }
    rescue Interrupt
      exit
    end

    # Starts an interactive IRB session examining the current object and its context.
    # This instance method provides a convenient way to debug objects without
    # explicitly passing bindings.
    #
    # @param binding [Binding, nil] The binding context to examine (defaults to TOPLEVEL_BINDING)
    # @return [void]
    #
    # @example Examine the current object
    #   my_object.examine
    #
    # @example Examine a specific variable
    #   data = [1, 2, 3]
    #   data.examine  # Inspects just the 'data' variable
    def examine(binding = TOPLEVEL_BINDING)
      IRB.examine(binding)
    end
  end
end
