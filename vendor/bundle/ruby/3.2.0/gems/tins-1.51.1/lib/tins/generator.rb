module Tins
  # This class can create generator objects, that can produce all tuples, that
  # would be created by as many for-loops as dimensions were given.
  #
  # The generator
  #  g = Tins::Generator[1..2, %w[a b c]]
  # produces
  #  g.to_a # => [[1, "a"], [1, "b"], [1, "c"], [2, "a"], [2, "b"], [2, "c"]]
  #
  # The 'each' method can be used to iterate over the tuples
  #  g.each { |a, b| puts "#{a} #{b}" }
  # and Tins::Generator includes the Enumerable module, so
  # Enumerable.instance_methods can be used as well:
  #  g.select { |a, b| %w[a c].include? b  } # => [[1, "a"], [1, "c"], [2, "a"], [2, "c"]]
  #
  class Generator
    include Enumerable

    # Create a new Generator object from the enumberables _enums_.
    def self.[](*enums)
      new(enums)
    end

    # Create a new Generator instance. Use the objects in the Array _enums_
    # as dimensions. The should all respond to the :each method (see module
    # Enumerable in the core ruby library).
    def initialize(enums)
      @enums, @iterators, @n = [], [], 0
      enums.each { |e| add_dimension(e) }
    end

    # Iterate over all tuples produced by this generator and yield to them.
    def each(&block) # :yield: tuple
      recurse(&block)
      self
    end

    # Recurses through nested enumerators to yield all combinations
    #
    # This method performs a recursive traversal of nested enumerators,
    # building tuples by iterating through each enumerator at its respective
    # level and yielding complete combinations when the deepest level is
    # reached
    #
    # @param tuple [ Array ] the current tuple being built during recursion
    # @param i [ Integer ] the current index/level in the recursion
    # @yield [ Array ] yields a duplicate of the completed tuple
    def recurse(tuple = [ nil ] * @n, i = 0, &block)
      if i < @n - 1 then
        @enums[i].__send__(@iterators[i]) do |x|
          tuple[i] = x
          recurse(tuple, i + 1, &block)
        end
      else
        @enums[i].__send__(@iterators[i]) do |x|
          tuple[i] = x
          yield tuple.dup
        end
      end
    end
    private :recurse

    # Add another dimension to this generator. _enum_ is an object, that ought
    # to respond to the _iterator_ method (defaults to :each).
    def add_dimension(enum, iterator = :each)
      @enums << enum
      @iterators << iterator
      @n += 1
    end

    # Return the size of this generator, that is the number of its dimensions.
    def size
      @enums.size
    end
  end
end
