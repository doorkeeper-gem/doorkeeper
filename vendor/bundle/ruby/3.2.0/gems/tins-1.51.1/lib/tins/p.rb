require 'pp'

module Tins
  # A module that provides debugging methods for inspecting objects by raising
  # exceptions with their inspected representations.
  #
  # This module adds p! and pp! methods that raise RuntimeError exceptions
  # containing the inspected or pretty-inspected output of objects, making it
  # easy to quickly debug values during development without printing to stdout.
  #
  # @example Using p! to inspect a single object
  #   p!(some_variable)
  #
  # @example Using pp! to inspect multiple objects
  #   pp!(first_var, second_var)
  module P
    private

    # Raises a RuntimeError with the inspected representation of the given
    # objects.
    #
    # This method is useful for quick debugging by raising an exception that
    # contains the inspected output of the provided objects. It behaves
    # similarly to Ruby's built-in +p+ method but raises an exception instead
    # of printing to stdout.
    #
    # @example Basic usage with single object
    #   p!(some_variable)
    #
    # @example Basic usage with multiple objects
    #   p!(first_var, second_var)
    #
    # @param objs [Array<Object>] One or more objects to inspect and raise
    # @raise [RuntimeError] Always raises a RuntimeError with inspected content
    def p!(*objs)
      raise((objs.size < 2 ? objs.first : objs).inspect)
    end

    # Raises a RuntimeError with the pretty-inspected representation of the
    # given objects.
    #
    # This method is useful for quick debugging by raising an exception that
    # contains the pretty-printed output of the provided objects. It behaves
    # similarly to Ruby's built-in +pp+ method but raises an exception instead
    # of printing to stdout.
    #
    # @example Basic usage with single object
    #   pp!(some_variable)
    #
    # @example Basic usage with multiple objects
    #   pp!(first_var, second_var)
    #
    # @param objs [Array<Object>] One or more objects to pretty-inspect and raise
    # @raise [RuntimeError] Always raises a RuntimeError with pretty-inspected content
    def pp!(*objs)
      raise("\n" + (objs.size < 2 ? objs.first : objs).pretty_inspect.chomp)
    end
  end
end
