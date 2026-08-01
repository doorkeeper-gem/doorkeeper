# frozen_string_literal: true

module Doorkeeper
  # A small thread-safe, fixed-TTL, in-memory memo keyed by URL. It exists
  # so one authorization flow (authorize GET, consent POST, token exchange)
  # does not refetch the same URL several times within a few seconds; it
  # deliberately implements no HTTP caching semantics.
  #
  # Only successfully fetched and validated values may be stored — an error
  # response or a malformed document must never be cached — which is
  # guaranteed by callers never yielding anything but a validated value.
  class DocumentCache
    DEFAULT_TTL = 60
    MAX_ENTRIES = 500

    def initialize(ttl: DEFAULT_TTL)
      @ttl = ttl
      @mutex = Mutex.new
      @store = {}
    end

    # Returns the cached document for the URL, or stores and returns the
    # block's result. The block's failures (raises, nil) are not cached.
    def fetch(url)
      cached = read(url)
      return cached if cached

      document = yield
      write(url, document) if document
      document
    end

    def clear
      @mutex.synchronize { @store.clear }
    end

    private

    def read(url)
      @mutex.synchronize do
        entry = @store[url]
        next nil unless entry

        if entry[:expires_at] <= monotonic_now
          @store.delete(url)
          next nil
        end

        entry[:document]
      end
    end

    def write(url, document)
      @mutex.synchronize do
        # Deleted first so a rewritten entry moves to the end of the hash's
        # insertion order, which is the end #prune evicts from. #read
        # already drops an entry when it finds it expired, so this only
        # matters when two threads resolve the same URL at once.
        @store.delete(url)
        prune
        @store[url] = { document: document, expires_at: monotonic_now + @ttl }
      end
    end

    # Drop expired entries; if the store is still full, drop the oldest
    # entries so a burst of unique URLs cannot grow the memo unbounded.
    def prune
      now = monotonic_now
      @store.delete_if { |_url, entry| entry[:expires_at] <= now }

      overflow = @store.size - (MAX_ENTRIES - 1)
      return if overflow <= 0

      @store.keys.first(overflow).each { |url| @store.delete(url) }
    end

    def monotonic_now
      Process.clock_gettime(Process::CLOCK_MONOTONIC)
    end
  end
end
