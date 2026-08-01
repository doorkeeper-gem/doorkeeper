# frozen_string_literal: true

require "singleton"

module Doorkeeper
  module OAuth
    module ClientAuthentication
      class PrivateKeyJwt
        # In-memory, process-local single-use guard for assertion jti values
        # (OIDC Core §9: an assertion may only be used once). Entries live
        # until the assertion's own exp, which PrivateKeyJwt caps at
        # MAX_LIFETIME, so the memory held here is bounded: at most
        # MAX_ENTRIES entries, each for at most MAX_LIFETIME seconds and of a
        # bounded size: PrivateKeyJwt caps the jti at MAX_JTI_LENGTH, and the
        # client_id it is keyed with is by then either a validated URL or the
        # uid of an application this server registered.
        #
        # Entries are partitioned by client. Keys arrive in the shape
        # PrivateKeyJwt.replay_key builds — "#{client_id.length}:#{client_id}:#{jti}"
        # — and the length prefix is what lets the client be read back out of
        # one unambiguously. The partition decides who pays when the guard is
        # full (see first_use?): a client that floods the guard with its own
        # assertions evicts its own entries, not the live replay records of
        # clients that had nothing to do with it. That matters once Client
        # ID Metadata Documents are enabled, since anyone can then publish a
        # private_key_jwt client and sign as many distinct assertions as they
        # like without registering anything. A key in any other shape is its
        # own partition.
        #
        # Being process-local this cannot catch a replay delivered to a
        # different server process (separate Puma workers, separate hosts).
        # Whether that matters depends on the deployment: the replay window
        # is at most MAX_LIFETIME anyway, and an attacker who can capture an
        # assertion in transit usually defeats TLS first. A deployment that
        # wants cross-process replay protection supplies a shared store
        # (backed by Redis or the like) through the
        # private_key_jwt_replay_guard config option.
        class ReplayGuard
          include Singleton

          # Upper bound on remembered jti values across all clients. When the
          # guard is full even after expired entries are pruned, an entry is
          # evicted rather than the new assertion rejected — see first_use?.
          MAX_ENTRIES = 10_000

          # A client holding more than this many entries when the guard is
          # full is the one evicted from — see first_use?. A hundredth of the
          # guard: no honest client needs a hundred live assertions per
          # process at once, while a flood from one client blows past it in
          # its first second.
          FLOOD_THRESHOLD = MAX_ENTRIES / 100

          # Expired entries are swept periodically rather than on every
          # authentication: the sweep is O(entries) and would otherwise run on
          # each request, walking up to MAX_ENTRIES every time. An entry that
          # outlives its exp by up to this long only makes the guard stricter,
          # never more permissive.
          SWEEP_INTERVAL = 10

          KEY_PREFIX = /\A(\d+):/

          def initialize
            @mutex = Mutex.new
            # key => expires_at, in insertion order: the front is the oldest
            # entry overall.
            @seen = {}
            # partition => { key => true }, each in insertion order too, so a
            # client's oldest entry is the front of its own hash.
            @held = {}
            @sweep_after = 0
            @full_sweep_at = -1
          end

          # @return [Boolean] true when the key was not seen before; the key
          #   is then remembered until +expires_at+ (unix time).
          def first_use?(key, expires_at:)
            now = Time.now.to_i

            @mutex.synchronize do
              sweep(now) if sweep_due?(now)

              return false if @seen.key?(key)

              # When full even after expiry pruning, evict rather than reject:
              # rejecting would let a flood of assertions lock legitimate
              # clients out entirely, while evicting only shortens the replay
              # window. Whose window is the question. A client holding more
              # than FLOOD_THRESHOLD entries is the flood (or a client so busy
              # that trimming its own oldest record costs it nothing), so its
              # oldest goes — not the live record of a client that had
              # nothing to do with it. Only when no client stands out like
              # that does the oldest entry overall go: a flooder spread thin
              # across many client_ids costs the others no more than the
              # plain FIFO would have, and is never handed the busiest honest
              # client as a victim to drain.
              evict_one while @seen.size >= MAX_ENTRIES

              @seen[key] = expires_at
              (@held[self.class.partition_of(key)] ||= {})[key] = true
              true
            end
          end

          def clear
            @mutex.synchronize do
              @seen.clear
              @held.clear
              @sweep_after = 0
              @full_sweep_at = -1
            end
          end

          # The client part of a key PrivateKeyJwt.replay_key built; any other
          # key is a partition of its own.
          def self.partition_of(key)
            key = key.to_s
            match = KEY_PREFIX.match(key)
            return key unless match

            key[0, match[0].length + match[1].to_i]
          end

          private

          # On the interval, and when full — but a guard kept full by a flood
          # of unexpired assertions would otherwise sweep on every call, so a
          # fullness-triggered sweep runs at most once a second; in between,
          # eviction keeps the size in check.
          def sweep_due?(now)
            return true if now >= @sweep_after
            return false unless @seen.size >= MAX_ENTRIES && now > @full_sweep_at

            @full_sweep_at = now
            true
          end

          def sweep(now)
            @seen.delete_if do |key, expiry|
              next false if expiry > now

              forget(key)
              true
            end
            @sweep_after = now + SWEEP_INTERVAL
          end

          def evict_one
            partition, entries = @held.max_by { |_, held| held.size }
            return if partition.nil?

            key = entries.size > FLOOD_THRESHOLD ? entries.first.first : @seen.first.first
            @seen.delete(key)
            forget(key)
          end

          def forget(key)
            partition = self.class.partition_of(key)
            entries = @held[partition]
            return unless entries

            entries.delete(key)
            @held.delete(partition) if entries.empty?
          end
        end
      end
    end
  end
end
