module Mize
  class << self

    # Clear all memoization caches at once.
    def cache_clear
      each_cache(&:clear)
    end

    private

    def each_cache
      Mize::MUTEX.synchronize do
        for cache in ObjectSpace.each_object(Mize::CacheProtocol)
          yield cache
        end
      end
      self
    end
  end
end
