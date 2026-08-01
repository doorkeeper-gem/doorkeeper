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
          # after expired entries are pruned, the oldest entries are evicted
          # rather than new assertions rejected — see first_use?.
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
