# frozen_string_literal: true

require "singleton"

module Doorkeeper
  module OAuth
    module ClientAuthentication
      class PrivateKeyJwt
        # In-memory, process-local single-use guard for assertion jti values
        # (OIDC Core §9: an assertion may only be used once). Entries live
        # until the assertion's own exp, which PrivateKeyJwt caps at
        # MAX_LIFETIME, so the memory held here is bounded.
        #
        # Being process-local this cannot catch a replay against a different
        # server process; a shared store is deliberately left as a follow-up
        # for the prototype.
        class ReplayGuard
          include Singleton

          MAX_ENTRIES = 10_000

          # Expired entries are swept periodically rather than on every
          # authentication: the sweep is O(entries) and would otherwise run on
          # each request, walking up to MAX_ENTRIES every time. An entry that
          # outlives its exp by up to this long only makes the guard stricter,
          # never more permissive.
          SWEEP_INTERVAL = 10

          def initialize
            @mutex = Mutex.new
            @seen = {}
            @sweep_after = 0
          end

          # @return [Boolean] true when the key was not seen before; the key
          #   is then remembered until +expires_at+ (unix time).
          def first_use?(key, expires_at:)
            now = Time.now.to_i

            @mutex.synchronize do
              if now >= @sweep_after || @seen.size >= MAX_ENTRIES
                @seen.delete_if { |_, expiry| expiry <= now }
                @sweep_after = now + SWEEP_INTERVAL
              end

              return false if @seen.key?(key)

              # When full even after expiry pruning, evict the oldest entries
              # rather than rejecting new assertions: rejecting would let a
              # flood of assertions lock legitimate clients out entirely,
              # while evicting only shortens the replay window under attack.
              @seen.shift while @seen.size >= MAX_ENTRIES

              @seen[key] = expires_at
              true
            end
          end

          def clear
            @mutex.synchronize do
              @seen.clear
              @sweep_after = 0
            end
          end
        end
      end
    end
  end
end
