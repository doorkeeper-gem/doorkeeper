module Tins
  # A module that allows grouping multiple modules together for type checking.
  #
  # This implementation creates a shared module that gets included in each of the
  # specified modules, enabling the use of `===` for type checking across all
  # grouped modules simultaneously.
  module ModuleGroup
    # Creates a new module group from the given modules.
    #
    # This method dynamically creates an anonymous module and includes it in
    # each of the provided modules. The returned module can then be used with
    # the `===` operator for type checking across all grouped modules.
    #
    # @note This modifies the included modules by adding the new module to their
    #   inheritance chain, which can have side effects in complex class hierarchies.
    #
    # @param modules [Array<Module>] One or more modules to include in this group
    # @return [Module] A new anonymous module that is included in all passed modules
    #
    # @example Creating a module group
    #   MyGroup = Tins::ModuleGroup[Array, String, Hash]
    #   MyGroup === []     # => true
    #   MyGroup === ""     # => true
    #   MyGroup === {}     # => true
    #
    #   case some_value
    #   when MyGroup
    #     handle_collection_or_string(some_value)
    #   end
    def self.[](*modules)
      modul = Module.new
      modules.each do |m|
        m.module_eval { include modul }
      end
      modul
    end
  end
end
