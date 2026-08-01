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
        # MAX_ENTRIES entries per pool (see below), each until the expiry
        # PrivateKeyJwt passes in — the assertion's own exp, capped at
        # MAX_LIFETIME, plus whatever leeway the host's global JWT decode
        # configuration carries — and of a bounded size: PrivateKeyJwt caps the jti at MAX_JTI_LENGTH, and the
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
        # like without registering anything — and spread them across as many
        # https:// client_ids as they like, too, which no per-client
        # accounting can catch. The partitions are therefore split further
        # into two pools, along the line trust splits: URL client_ids, which
        # anyone can mint, and everything else, which only the host mints
        # (registered uids, and keys in any other shape, each of which is its
        # own partition). The two pools are accounted separately, each with
        # its own MAX_ENTRIES ceiling, so neither can evict the other's
        # entries and neither can fill the guard on the other's behalf: a URL
        # flood cannot shorten a registered client's replay window, and
        # registered traffic cannot leave document clients with no room to be
        # remembered in. Which pool an entry is in is carried on its key: a
        # document client's key is marked with URL_POOL_PREFIX by
        # PrivateKeyJwt.replay_key, from the provenance it has established
        # (a row this feature materialized, or no row at all), and the guard
        # reads the mark back rather than judging a uid by its shape — a
        # registered application may hold an https:// uid too (a
        # pre-registered Client Identifier URL, draft Section 7.2), and with
        # the feature off every uid is a registered one.
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

          # Upper bound on remembered jti values in one pool. When a pool is
          # full even after expired entries are pruned, an entry from that
          # same pool is evicted rather than the new assertion rejected — see
          # first_use?. Two pools, so twice this many entries is the ceiling
          # on what the guard holds.
          MAX_ENTRIES = 10_000

          # A client presenting a new assertion into a full pool while
          # already holding more than this many entries evicts its own oldest
          # instead of another client's in that pool — see first_use?. A
          # hundredth of a pool: a client that busy may well be honest, and
          # trimming its oldest costs it only the tail of its own replay
          # window, while a flood from one client blows past it in its first
          # second.
          FLOOD_THRESHOLD = MAX_ENTRIES / 100

          # Expired entries are swept periodically rather than on every
          # authentication: the sweep is O(entries) and would otherwise run on
          # each request, walking up to MAX_ENTRIES every time. An entry that
          # outlives its exp by up to this long only makes the guard stricter,
          # never more permissive.
          SWEEP_INTERVAL = 10

          # Ahead of the length prefix on the key of every URL-pool entry —
          # put there by PrivateKeyJwt.replay_key for a client whose
          # client_id resolves through its metadata document, and by nothing
          # else. Only a key in exactly that shape is in the pool (see
          # url_partition?).
          URL_POOL_PREFIX = "url:"

          KEY_PREFIX = /\A(?:#{Regexp.escape(URL_POOL_PREFIX)})?(\d+):/
          URL_KEY_PREFIX = /\A#{Regexp.escape(URL_POOL_PREFIX)}\d+:/

          def initialize
            @mutex = Mutex.new
            # key => expires_at, in insertion order: the front is the oldest
            # entry overall.
            @seen = {}
            # partition => { key => true }, each in insertion order too, so a
            # client's oldest entry is the front of its own hash.
            @held = {}
            # @seen split by pool, in the same insertion order, so each pool's
            # oldest entry is the front of its own hash and neither pool has
            # to be found by walking the other — see evict_one.
            @url_seen = {}
            @plain_seen = {}
            # identity => true: what "used already" is asked of, which is the
            # key without its pool mark. The mark says who pays for the entry,
            # not who the assertion is from — the same (client_id, jti) reaches
            # the two pools whenever the uid's provenance changes while the
            # assertion is still alive (a URL a document client materialized
            # gets registered, or a materialized row is adopted by clearing its
            # stamp), and a jti is single-use per client either way (OIDC Core
            # §9). Kept apart from @seen so eviction and the flood accounting
            # go on being pool-exact.
            @identities = {}
            @sweep_after = 0
            @full_sweep_at = -1
          end

          # @return [Boolean] true when the key was not seen before; the key
          #   is then remembered until +expires_at+ (unix time).
          def first_use?(key, expires_at:)
            now = Time.now.to_i
            partition = self.class.partition_of(key)
            pool = self.class.url_partition?(partition) ? @url_seen : @plain_seen

            identity = self.class.identity_of(key)

            @mutex.synchronize do
              sweep(now) if sweep_due?(now)

              return false if @identities.key?(identity)

              # When the arriving client's pool is full even after expiry
              # pruning, evict rather than reject: rejecting would let a flood
              # of assertions lock legitimate clients out entirely, while
              # evicting only shortens the replay window. Whose window is the
              # question, and it is never a question the other pool has to
              # answer — each is accounted on its own, so a URL flood cannot
              # cost a registered client an entry and registered traffic
              # cannot leave document clients no room. Within a pool, a client
              # presenting yet another assertion while already holding more
              # than FLOOD_THRESHOLD entries pays for it itself: its own
              # oldest record goes, whether it is the flood or merely a client
              # so busy that trimming its oldest costs it little. Every other
              # arrival evicts the oldest entry in its pool, exactly as a
              # plain FIFO would within it. What eviction never does is single
              # out whichever client happens to hold the most entries: that
              # would hand a flood spread thin across many one-entry
              # client_ids the busiest honest client as a victim, draining
              # its live replay records while the flood's own older entries
              # stay put.
              while pool.size >= MAX_ENTRIES
                return false unless evict_one(partition, pool)
              end

              @seen[key] = expires_at
              @identities[identity] = true
              pool[key] = true
              (@held[partition] ||= {})[key] = true
              true
            end
          end

          def clear
            @mutex.synchronize do
              @seen.clear
              @identities.clear
              @held.clear
              @url_seen.clear
              @plain_seen.clear
              @sweep_after = 0
              @full_sweep_at = -1
            end
          end

          # The client part of a key PrivateKeyJwt.replay_key built, its pool
          # mark included; any other key is a partition of its own.
          def self.partition_of(key)
            key = key.to_s
            match = KEY_PREFIX.match(key)
            return key unless match

            key[0, match[0].length + match[1].to_i]
          end

          # Whether the partition belongs to the URL pool, read off the key:
          # PrivateKeyJwt.replay_key marks a document client's key, and only
          # such a key, with URL_POOL_PREFIX. The shape of the uid decides
          # nothing here. A registered application may hold an https:// uid
          # (a pre-registered Client Identifier URL, draft Section 7.2), and
          # with the feature off every https:// uid is one: the key built for
          # either carries no mark, so their live replay records are never a
          # URL flood's to evict, and the guard is for them the one plain FIFO
          # it always was. A key in any other shape was built by host code,
          # which only a registered client reaches, so it stays out of the
          # pool anyone can flood — even one that happens to start with the
          # mark.
          def self.url_partition?(partition)
            URL_KEY_PREFIX.match?(partition)
          end

          # What single use is counted against: the key with its pool mark
          # taken off, so that one (client_id, jti) is one use whichever pool
          # it lands in. Only a key the mark actually applies to loses it — a
          # host-built key that merely starts with those characters is not in
          # the URL pool (see url_partition?) and keeps every byte it has.
          def self.identity_of(key)
            key = key.to_s
            URL_KEY_PREFIX.match?(key) ? key.delete_prefix(URL_POOL_PREFIX) : key
          end

          private

          # On the interval, and when full — but a guard kept full by a flood
          # of unexpired assertions would otherwise sweep on every call, so a
          # fullness-triggered sweep runs at most once a second; in between,
          # eviction keeps the size in check.
          def sweep_due?(now)
            return true if now >= @sweep_after
            return false unless (@url_seen.size >= MAX_ENTRIES || @plain_seen.size >= MAX_ENTRIES) &&
                                now > @full_sweep_at

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

          # Evicts one entry from the arriving client's own pool: its own
          # oldest when it is holding more than FLOOD_THRESHOLD of the pool's
          # entries, and otherwise the pool's oldest. A pool this is called for
          # is full, so there is always something to take.
          #
          # @return [Boolean] false when the pool held nothing to evict, which
          #   leaves the arrival rejected rather than another pool drained.
          def evict_one(partition, pool)
            held = @held[partition]
            key = held && held.size > FLOOD_THRESHOLD ? held.first.first : pool.first&.first
            return false unless key

            @seen.delete(key)
            forget(key)
            true
          end

          def forget(key)
            @identities.delete(self.class.identity_of(key))
            @url_seen.delete(key)
            @plain_seen.delete(key)
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
