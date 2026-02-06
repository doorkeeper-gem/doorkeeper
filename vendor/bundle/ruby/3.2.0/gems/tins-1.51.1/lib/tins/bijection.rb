module Tins
  # A hash subclass that ensures bijection between keys and values
  class Bijection < Hash
    # Creates a new Bijection instance with key-value pairs.
    #
    # @param pairs [Array] an array of key-value pairs to populate the
    # bijection
    #
    # @return [Bijection] a new bijection populated with the provided pairs
    def self.[](*pairs)
      pairs.size % 2 == 0 or
        raise ArgumentError, "odd number of arguments for #{self}"
      new.fill do |obj|
        (pairs.size / 2).times do |i|
          j = 2 * i
          key = pairs[j]
          value = pairs[j + 1]
          obj.key?(key) and raise ArgumentError, "duplicate key #{key.inspect} for #{self}"
          obj.inverted.key?(value) and raise ArgumentError, "duplicate value #{value.inspect} for #{self}"
          obj[pairs[j]] = pairs[j + 1]
        end
      end
    end

    # The initialize method sets up a new instance with an inverted bijection.
    #
    # @param inverted [ Bijection ] the inverted bijection object, defaults to
    # a new Bijection instance
    def initialize(inverted = Bijection.new(self))
      @inverted = inverted
    end

    # The fill method populates the object with content from a block if it is
    # empty.
    #
    # @return [ self ] returns the object itself after filling or if it was not
    # empty
    # @yield [ self ] yields self to the block for population
    def fill
      if empty?
        yield self
        freeze
      end
      self
    end

    # The freeze method freezes the current object and its inverted attribute.
    #
    # @return [Object] the frozen object
    def freeze
      r = super
      unless @inverted.frozen?
        @inverted.freeze
      end
      r
    end

    # The []= method assigns a value to a key in the hash and maintains an
    # inverted index.
    #
    # @param key [ Object ] the key to assign
    # @param value [ Object ] the value to assign
    #
    # @return [ Object ] the assigned value
    #
    # @note This method will not overwrite existing keys, it will return early
    # if the key already exists.
    def []=(key, value)
      key?(key) and return
      super
      @inverted[value] = key
    end

    # The inverted attribute returns the inverted state of the object.
    # Creates a new Bijection instance filled with key-value pairs.
    #
    # @return [Bijection] a new bijection instance with the specified key-value pairs
    attr_reader :inverted
  end
end
