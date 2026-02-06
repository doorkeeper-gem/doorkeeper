module Tins
  # An LRU (Least Recently Used) cache implementation.
  #
  # This cache maintains a fixed-size collection of key-value pairs,
  # automatically removing the least recently accessed item when the capacity
  # is exceeded. Both read and write are considered access.
  class LRUCache
    include Enumerable

    # Initializes a new LRU cache with the specified capacity.
    #
    # @param capacity [Integer] maximum number of items the cache can hold
    def initialize(capacity)
      @capacity = Integer(capacity)
      @capacity >= 1 or
        raise ArgumentError, "capacity should be >= 1, was #@capacity"
      @data     = {} # Least-recently used will always be the first element
    end

    # Returns the maximum capacity of the cache.
    #
    # @return [Integer] the cache capacity
    attr_reader :capacity

    # Retrieves the value associated with the given key.
    #
    # If the key exists, it is moved to the most recently used position.
    # Returns nil if the key does not exist.
    #
    # @param key [Object] the key to look up
    # @return [Object, nil] the value for the key or nil if not found
    def [](key)
      if @data.has_key?(key)
        @data[key] = @data.delete(key)
      end
    end

    # Associates a value with a key in the cache.
    #
    # If the key already exists, its position is updated to most recently used.
    # If adding this item exceeds the capacity, the least recently used item is
    # removed.
    #
    # @param key [Object] the key to set
    # @param value [Object] the value to associate with the key
    # @return [Object] the assigned value
    def []=(key, value)
      @data.delete(key)
      @data[key] = value
      if @data.size > @capacity
        @data.shift
      end
      value
    end

    # Iterates over all key-value pairs in the cache.
    #
    # Items are yielded in order from most recently used to least recently used.
    #
    # @yield [key, value] yields each key-value pair
    # @yieldparam key [Object] the key
    # @yieldparam value [Object] the value
    # @return [Enumerator] if no block is given
    def each(&block)
      @data.reverse_each(&block)
    end

    # Removes and returns the value associated with the given key.
    #
    # @param key [Object] the key to delete
    # @return [Object, nil] the removed value or nil if not found
    def delete(key)
      @data.delete(key)
    end

    # Removes all items from the cache.
    #
    # @return [Tins::LRUCache] self
    def clear
      @data.clear
      self
    end

    # Returns the number of items currently in the cache.
    #
    # @return [Integer] the current size of the cache
    def size
      @data.size
    end
  end
end
