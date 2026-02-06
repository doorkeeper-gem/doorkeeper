require 'tins/concern'

module Tins
  # Concern provides a mechanism for module configuration that persists across
  # inheritance and inclusion boundaries using thread-local storage.
  #
  # This module implements a pattern where modules can be configured with
  # arguments that are then available throughout the module's lifecycle in
  # a thread-safe manner. It's particularly useful for implementing
  # configuration-based concerns that need to maintain state across
  # different scopes.
  #
  # @example Configured concern usage
  #   module MyConcern
  #     extend Tins::Concern
  #   end
  #
  #   # Configure the concern with parameters
  #   include MyConcern.tins_concern_configure(:option1, :option2)
  module Concern
    # ModuleMixin provides thread-local storage for concern configuration.
    #
    # This mixin adds methods to any module that includes it, allowing for
    # configuration of concerns through thread-local storage. The configuration
    # is stored in the current thread's context and persists during the
    # execution of code that uses this concern.
    #
    # @note This implementation relies on Thread.current which makes it
    # thread-safe but scoped to individual threads.
    module ModuleMixin
      # Configures the module with the given arguments and returns self.
      #
      # This method stores the provided arguments in thread-local storage,
      # making them available via {tins_concern_args}. It's designed to be
      # chainable (returns self).
      #
      # @param args [Array] Arguments to configure this concern with
      # @return [Module] The module itself, for chaining
      # @example
      #   MyConcern.tins_concern_configure(:option1, :option2)
      def tins_concern_configure(*args)
        Thread.current[:tin_concern_args] = args
        self
      end

      # Retrieves the current concern configuration arguments.
      #
      # This method fetches the arguments that were previously set using
      # {tins_concern_configure}. If no configuration has been set, it returns
      # nil.
      #
      # @return [Array, nil] The stored configuration arguments or nil
      # @example
      #   MyConcern.tins_concern_configure(:option1, :option2)
      #   puts MyConcern.tins_concern_args  # => [:option1, :option2]
      def tins_concern_args
        Thread.current[:tin_concern_args]
      end
    end
  end

  # Extends the core Module class with the concern functionality.
  #
  # This line makes the concern configuration methods available to all modules
  # in the system, allowing any module to be configured as a concern.
  #
  # @see Tins::Concern::ModuleMixin
  class ::Module
    include Tins::Concern::ModuleMixin
  end
end
