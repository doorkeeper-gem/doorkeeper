require 'tins/thread_local'

module Tins
  # This module provides recursive symbolization of hash keys. It handles
  # nested structures including hashes and arrays, with special handling for
  # circular references to prevent infinite recursion.
  #
  # @example Basic usage
  #   hash = { "name" => "John", "address" => { "street" => "123 Main St" } }
  #   hash.symbolize_keys_recursive
  #   # => { name: "John", address: { street: "123 Main St" } }
  #
  # @example Handling circular references
  #   hash = { "name" => "John" }
  #   hash["self"] = hash  # Circular reference
  #   hash.symbolize_keys_recursive(circular: "[Circular Reference]")
  #   # => { name: "John", self: "[Circular Reference]" }
  module HashSymbolizeKeysRecursive
    extend Tins::ThreadLocal

    # Thread-local storage for tracking visited objects to handle circular
    # references
    thread_local :seen

    # Recursively converts all string keys in a hash (and nested hashes/arrays)
    # to symbols. This method does not modify the original hash.
    #
    # @param circular [Object] The value to use when encountering circular references.
    #   Defaults to nil, which means circular references will be ignored.
    # @return [Hash, Array, Object] A new hash/array with symbolized keys
    #
    # @example Basic usage
    #   { "name" => "John", "age" => 30 }.symbolize_keys_recursive
    #   # => { name: "John", age: 30 }
    #
    # @example Nested structures
    #   {
    #     "user" => {
    #       "name" => "John",
    #       "hobbies" => ["reading", "swimming"]
    #     }
    #   }.symbolize_keys_recursive
    #   # => { user: { name: "John", hobbies: ["reading", "swimming"] } }
    #
    # @example Circular reference handling
    #   hash = { "name" => "John" }
    #   hash["self"] = hash
    #   hash.symbolize_keys_recursive(circular: "[Circular]")
    #   # => { name: "John", self: "[Circular]" }
    def symbolize_keys_recursive(circular: nil)
      self.seen = {}
      _symbolize_keys_recursive(self, circular: circular)
    ensure
      self.seen = nil
    end

    # Recursively converts all string keys in a hash (and nested hashes/arrays)
    # to symbols. This method modifies the original hash in place.
    #
    # @param circular [Object] The value to use when encountering circular references.
    #   Defaults to nil, which means circular references will be ignored.
    # @return [Hash, Array, Object] The same hash/array with symbolized keys
    #
    # @example Basic usage
    #   hash = { "name" => "John", "age" => 30 }
    #   hash.symbolize_keys_recursive!
    #   # => { name: "John", age: 30 }
    #   # hash is now modified in place
    def symbolize_keys_recursive!(circular: nil)
      replace symbolize_keys_recursive(circular: circular)
    end

    private

    # Performs the actual recursive symbolization work
    #
    # @param object [Object] The object to process
    # @param circular [Object] The value to return for circular references
    # @return [Object] The processed object with symbolized keys
    def _symbolize_keys_recursive(object, circular: nil)
      case
      when seen[object.__id__]
        object = circular
      when object.respond_to?(:to_hash)
        object = object.to_hash
        seen[object.__id__] = true
        new_object = object.class.new
        seen[new_object.__id__] = true
        object.each do |k, v|
          new_object[k.to_s.to_sym] = _symbolize_keys_recursive(v, circular: circular)
        end
        object = new_object
      when object.respond_to?(:to_ary)
        object = object.to_ary
        seen[object.__id__] = true
        new_object = object.class.new(object.size)
        seen[new_object.__id__] = true
        object.each_with_index do |v, i|
          new_object[i] = _symbolize_keys_recursive(v, circular: circular)
        end
        object = new_object
      end
      object
    end
  end
end
