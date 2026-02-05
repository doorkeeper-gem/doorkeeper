require 'set'

module Tins
  # NamedSet extends Ruby's Set class to include a descriptive name.
  #
  # This class provides all the functionality of Ruby's standard Set while
  # adding a named identifier that can be useful for debugging, logging, and
  # identification purposes. The name is stored as an instance variable and can
  # be accessed or modified
  # through the `name` accessor.
  #
  # @example Basic usage
  #   set = Tins::NamedSet.new("user_roles")
  #   set.add(:admin)
  #   set.add(:user)
  #   puts set.name  # => "user_roles"
  #   puts set.to_a  # => [:admin, :user]
  class NamedSet < Set
    # Initializes a new NamedSet with the given name.
    #
    # @param name [String] A descriptive name for this set
    def initialize(name)
      @name = name
      super()
    end

    # Gets or sets the name of this NamedSet.
    #
    # @return [String] The current name of the set
    attr_accessor :name
  end
end
