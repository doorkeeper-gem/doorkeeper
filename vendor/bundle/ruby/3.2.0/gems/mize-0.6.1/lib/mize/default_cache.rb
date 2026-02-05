require 'monitor'

class Mize::DefaultCache
  include Mize::CacheProtocol
  include MonitorMixin

  def initialize
    @data = {}
  end

  # Clear the cache by removing all entries from the cache
  def clear(options = nil)
    @data.clear
    self
  end

  # Determine whether a cache entry exists in this cache.
  #
  # @param name [String] The name of the cache entry to check.
  # @return [Boolean] Whether or not the cache entry exists.
  def exist?(name, options = nil)
    @data.key?(name)
  end

  # Read a value from the cache by name. If the entry does not exist in the
  # cache, it will return nil.
  #
  # @param name [String] The name of the cache entry to read.
  # @return [Object] The value stored in the cache for the given name.
  def read(name, options = nil)
    @data.fetch(name, nil)
  end

  # Write a value to the cache by name. If an entry with the same name already
  # exists in the cache, it will be overwritten.
  #
  # @param name [String] The name of the cache entry to write.
  # @param value [Object] The value to store in the cache for the given name.
  # @return [Object] The value stored in the chache.
  def write(name, value, options = nil)
    @data.store(name, value)
  end

  # Delete a cache entry by name. If the entry does not exist in the cache, it
  # will do nothing.
  #
  # @param name [String] The name of the cache entry to delete.
  # @return [Object] The value stored in the chache before deletion.
  def delete(name, options = nil)
    @data.delete(name)
  end

  # Each name of the cache is yielded to the block.
  # @return [self]
  def each_name(&block)
    @data.each_key(&block)
    self
  end

  # Initialize a duplicate of this cache.
  # @param other [Mize::DefaultCache] The other cache to initialize a duplicate of.
  def initialize_dup(other)
    super
    other.instance_variable_set :@data, @data.dup
  end

  alias prototype dup
end
