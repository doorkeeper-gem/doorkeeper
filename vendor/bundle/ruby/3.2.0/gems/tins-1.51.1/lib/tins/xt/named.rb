module Tins
  # A dynamically created module class used internally by the
  # {Tins::Object#named} and {Tins::Module#named} methods to create dynamic
  # methods.
  #
  # This class inherits from Module and serves as a template for creating
  # dynamically scoped methods that can be extended or included into objects
  # or classes.
  Named = ::Class.new(::Module)

  class ::Object
    # Adds a dynamically created method to the object instance. The method will
    # call the specified +method+ with optional +args+ and combine any provided
    # +named_block+ with runtime blocks.
    #
    # @param name [Symbol] The name of the method to create
    # @param method [Symbol] The existing method to delegate to
    # @param args [Array] Optional arguments to pre-bind to the delegated method
    # @yield [Object] Optional block to be used as the method's block
    # @return [Object] self
    # @example Create a method that maps elements
    #   a = [1, 2, 3]
    #   a.named(:double, :map) { |x| x * 2 }
    #   a.double  # => [2, 4, 6]
    #
    # @example Pre-bind arguments to a method
    #   def process(data, multiplier, &block)
    #     data.map { |x| block.call(x * multiplier) }
    #   end
    #
    #   Object.named(:process_by_10, :process, 10) do |result|
    #     result + 1
    #   end
    #   process_by_10([1, 2, 3]) { |x| x * 2 }  # => [21, 41, 61]
    def named(name, method, *args, &named_block)
      name = name.to_sym
      m = Tins::Named.new {
        define_method(name) do |*rest, &block|
          block = named_block if named_block
          __send__(method, *(args + rest), &block)
        end
      }
      if m.respond_to?(:set_temporary_name)
        m.set_temporary_name "#{m.class} for method #{name.inspect}"
      end
      extend m
    end
  end

  class ::Module
    # Adds a dynamically created method to all instances of the class. The
    # method will call the specified +method+ with optional +args+ and combine
    # any provided +named_block+ with runtime blocks.
    #
    # @param name [Symbol] The name of the method to create
    # @param method [Symbol] The existing method to delegate to
    # @param args [Array] Optional arguments to pre-bind to the delegated method
    # @yield [Object] Optional block to be used as the method's block
    # @return [Module] self
    #
    # @example Create a class-level method
    #   Array.named(:sum_all, :reduce) { |acc, x| acc + x }
    #   [1, 2, 3].sum_all  # => 6
    def named(name, method, *args, &named_block)
      name = name.to_sym
      m = Tins::Named.new {
        define_method(name) do |*rest, &block|
          block = named_block if named_block
          __send__(method, *(args + rest), &block)
        end
      }
      if m.respond_to?(:set_temporary_name)
        m.set_temporary_name "#{m.class} for method #{name.inspect}"
      end
      include m
    end
  end
end
