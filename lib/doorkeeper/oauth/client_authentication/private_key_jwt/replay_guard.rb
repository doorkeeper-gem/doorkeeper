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
        # MAX_ENTRIES entries, each until the expiry PrivateKeyJwt passes in
        # — the assertion's own exp, capped at MAX_LIFETIME, plus whatever
        # leeway the host's global JWT decode configuration carries — and of
        # a bounded size: PrivateKeyJwt caps the jti at MAX_JTI_LENGTH, and
        # the client_id it is keyed with is the uid of an application this
        # server registered.
        #
        # Entries are partitioned by client. Keys arrive in the shape
        # PrivateKeyJwt.replay_key builds — "#{client_id.length}:#{client_id}:#{jti}"
        # — and the length prefix is what lets the client be read back out of
        # one unambiguously. The partition decides who pays when the guard is
        # full (see first_use?): a client that floods the guard with its own
        # assertions evicts its own entries, not the live replay records of
        # clients that had nothing to do with it.
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

          # Upper bound on remembered jti values. When the guard is full even
          # after expired entries are pruned, an entry is evicted rather than
          # the new assertion rejected — see first_use?.
          MAX_ENTRIES = 10_000

          # A client presenting a new assertion into a full guard while
          # already holding more than this many entries evicts its own oldest
          # instead of another client's — see first_use?. A hundredth of the
          # guard: a client that busy may well be honest, and trimming its
          # oldest costs it only the tail of its own replay window, while a
          # flood from one client blows past it in its first second.
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
            partition = self.class.partition_of(key)

            @mutex.synchronize do
              sweep(now) if sweep_due?(now)

              return false if @seen.key?(key)

              # When full even after expiry pruning, evict rather than reject:
              # rejecting would let a flood of assertions lock legitimate
              # clients out entirely, while evicting only shortens the replay
              # window. Whose window is the question. A client presenting yet
              # another assertion while already holding more than
              # FLOOD_THRESHOLD entries pays for it itself: its own oldest
              # record goes, whether it is the flood or merely a client so busy
              # that trimming its oldest costs it little. Every other arrival
              # evicts the oldest entry overall, exactly as a plain FIFO would.
              # What eviction never does is single out whichever client
              # happens to hold the most entries: that would hand a flood
              # spread thin across many one-entry client_ids the busiest
              # honest client as a victim, draining its live replay records
              # while the flood's own older entries stay put.
              evict_one(partition) while @seen.size >= MAX_ENTRIES

              @seen[key] = expires_at
              (@held[partition] ||= {})[key] = true
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

          # Evicts one entry: the arriving client's own oldest when it is
          # holding more than FLOOD_THRESHOLD entries, and otherwise the oldest
          # overall. The guard this is called on is full, so there is always
          # something to take.
          def evict_one(partition)
            held = @held[partition]
            key = held && held.size > FLOOD_THRESHOLD ? held.first.first : @seen.first.first

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
