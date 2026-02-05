module Tins
  # A module that provides a convenient way to check if objects respond to
  # specific methods.
  #
  # The `responding?` method returns an object that can be used with the
  # case/when construct to test if an object responds to certain methods. This is
  # particularly useful for duck typing and implementing polymorphic behavior.
  #
  # @example Check duck types
  #   if responding?(:eof?, :gets) === obj
  #     until obj.eof?
  #       puts obj.gets
  #     end
  #  end
  #
  # @example Easy interface checks
  #   case obj
  #   when responding?(:length, :keys)
  #     puts "  → Hash-like object (has size and keys)"
  #   when responding?(:size, :begin)
  #     puts "  → Range-like object (has size and begin)"
  #   when responding?(:length, :push)
  #     puts "  → Array-like object (has size and push)"
  #   when responding?(:length, :upcase)
  #     puts "  → String-like object (has length and upcase)"
  #   when responding?(:read, :write)
  #     puts "  → IO-like object (has read and write)"
  #   else
  #     puts "  → Unknown interface"
  #   end
  module Responding
    # Returns a special object that can be used to test if objects respond to
    # specific methods. The returned object implements `===` to perform the
    # check.
    #
    # This is particularly useful for duck typing and case/when constructs
    # where you want to match against objects based on their interface rather
    # than their class.
    #
    # @param method_names [Array<Symbol>] One or more method names to check for
    # @return [Object] A special object that responds to `===` for method checking
    def responding?(*method_names)
      Class.new do
        define_method(:to_s) do
          "Responding to #{method_names * ', '}"
        end

        alias inspect to_s

        define_method(:===) do |object|
          method_names.all? do |method_name|
            object.respond_to?(method_name)
          end
        end
      end.new
    end
  end
end
