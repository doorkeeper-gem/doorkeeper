require 'tins/thread_local'

module Tins
  # HashBFS module for breadth-first traversal of hash structures
  #
  # Provides methods to traverse hash structures in a breadth-first manner,
  # visiting all keys and values while maintaining the order of traversal.
  module HashBFS
    extend Tins::ThreadLocal

    thread_local :seen

    # The bfs method performs a breadth-first search on the object's structure,
    # visiting all elements and yielding their indices and values to the block.
    #
    # @param visit_internal [ true, false ] whether to visit internal hashes or arrays
    # @yield [ index, value ] yields each element's index and value to the block
    #
    # @raise [ ArgumentError ] if no &block argument was provided
    #
    # @example bfs { |index, value| … } # performs a breadth-first search on the object's structure
    #
    # @return [ self ] returns the receiver
    def bfs(visit_internal: false, &block)
      block or raise ArgumentError, 'require &block argument'
      self.seen = {}
      queue     = []
      queue.push([ nil, self ])
      while (index, object = queue.shift)
        case
        when seen[object.__id__]
          next
        when Hash === object
          seen[object.__id__] = true
          object.each do |k, v|
            queue.push([ k, convert_to_hash_or_ary(v) ])
          end
          visit_internal or next
        when Array === object
          seen[object.__id__] = true
          object.each_with_index do |v, i|
            queue.push([ i, convert_to_hash_or_ary(v) ])
          end
          visit_internal or next
        end
        block.(index, object)
      end
      self
    ensure
      self.seen = nil
    end

    # Converts the given object into a hash or array if possible
    #
    # @param object [Object] The object to convert
    #
    # @return [Hash, Array, Object] The converted object or itself if not convertible
    def convert_to_hash_or_ary(object)
      case
      when object.respond_to?(:to_hash)
        object.to_hash
      when object.respond_to?(:to_ary)
        object.to_ary
      else
        object
      end
    end
  end
end
