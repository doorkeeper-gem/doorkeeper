# frozen_string_literal: true

require "spec_helper"

RSpec.describe Doorkeeper::OAuth::ClientAuthentication::PrivateKeyJwt::ReplayGuard do
  subject(:guard) { described_class.instance }

  let(:far_future) { Time.now.to_i + 600 }

  def key_for(client_id, jti)
    "#{client_id.length}:#{client_id}:#{jti}"
  end

  # The key PrivateKeyJwt.replay_key builds for a document client.
  def url_key_for(client_id, jti)
    "#{described_class::URL_POOL_PREFIX}#{key_for(client_id, jti)}"
  end

  it "remembers a key until it expires" do
    expect(guard.first_use?(key_for("client", "a"), expires_at: far_future)).to be true
    expect(guard.first_use?(key_for("client", "a"), expires_at: far_future)).to be false
  end

  it "forgets an expired key once the guard is full" do
    stub_const("#{described_class}::MAX_ENTRIES", 2)
    guard.first_use?(key_for("client", "stale"), expires_at: Time.now.to_i - 1)
    guard.first_use?(key_for("client", "fresh"), expires_at: far_future)

    # Full: the sweep runs, prunes the expired entry and leaves room.
    expect(guard.first_use?(key_for("client", "newer"), expires_at: far_future)).to be true
    expect(guard.first_use?(key_for("client", "fresh"), expires_at: far_future)).to be false
  end

  # A jti is single-use per client (OIDC Core §9), and which pool an entry is
  # accounted in is about who pays for the memory, not about who the assertion
  # is from. The same URL reaches both pools while an assertion is still alive
  # whenever its provenance changes — a URL a document client materialized gets
  # registered (draft Section 7.2), or a materialized row is adopted by clearing
  # its stamp — and the assertion must not become usable a second time for it.
  it "counts one use whichever pool the same client and jti land in" do
    expect(guard.first_use?(url_key_for("https://c.example/x", "j"), expires_at: far_future)).to be true
    expect(guard.first_use?(key_for("https://c.example/x", "j"), expires_at: far_future)).to be false
  end

  it "counts one use in the other order too" do
    expect(guard.first_use?(key_for("https://c.example/x", "j"), expires_at: far_future)).to be true
    expect(guard.first_use?(url_key_for("https://c.example/x", "j"), expires_at: far_future)).to be false
  end

  # Only the mark PrivateKeyJwt.replay_key puts there is taken off. A key host
  # code built that merely starts with those characters is not in the URL pool
  # and keeps every byte it has, so it is nobody else's use.
  it "leaves a key that only looks marked alone" do
    expect(guard.first_use?("#{described_class::URL_POOL_PREFIX}opaque", expires_at: far_future)).to be true
    expect(guard.first_use?("opaque", expires_at: far_future)).to be true
  end

  describe ".partition_of" do
    it "reads the client out of a key PrivateKeyJwt.replay_key built" do
      client_id = "https://a.example/c"

      expect(described_class.partition_of(key_for(client_id, "jti:with:colons")))
        .to eq("#{client_id.length}:#{client_id}")
    end

    it "tells apart clients that are prefixes of each other" do
      expect(described_class.partition_of(key_for("client", "x:y")))
        .not_to eq(described_class.partition_of(key_for("client:x", "y")))
    end

    it "reads the client out of a URL-pool key, mark included" do
      client_id = "https://a.example/c"

      expect(described_class.partition_of(url_key_for(client_id, "jti:with:colons")))
        .to eq("#{described_class::URL_POOL_PREFIX}#{client_id.length}:#{client_id}")
    end

    it "treats a key in any other shape as its own partition" do
      expect(described_class.partition_of("opaque")).to eq("opaque")
    end
  end

  # Which pool a client is in is a matter of provenance, decided where the
  # key is built (PrivateKeyJwt.replay_key) and read back off it here — never
  # off the shape of the uid, which cannot tell a document client from a
  # pre-registered Client Identifier URL (draft Section 7.2).
  describe ".url_partition?" do
    it "is true for the partition of a key marked as a document client's" do
      partition = described_class.partition_of(url_key_for("https://a.example/c", "x"))

      expect(described_class.url_partition?(partition)).to be true
    end

    it "is false for an https uid whose key carries no mark" do
      partition = described_class.partition_of(key_for("https://a.example/c", "x"))

      expect(described_class.url_partition?(partition)).to be false
    end

    it "is false for a key in any other shape, even one starting with the mark" do
      partition = described_class.partition_of("#{described_class::URL_POOL_PREFIX}opaque")

      expect(described_class.url_partition?(partition)).to be false
    end
  end

  # Anyone can publish a private_key_jwt Client ID Metadata Document and
  # sign as many distinct assertions as they like, so whoever fills the guard
  # must be the one whose entries are evicted — not a client whose captured
  # assertion is still within its exp.
  context "when full of one client's unexpired assertions" do
    before do
      stub_const("#{described_class}::MAX_ENTRIES", 4)
      stub_const("#{described_class}::FLOOD_THRESHOLD", 1)
    end

    it "evicts the flooding client's own entries rather than another client's live record" do
      expect(guard.first_use?(key_for("victim", "captured"), expires_at: far_future)).to be true

      10.times do |i|
        expect(guard.first_use?(key_for("https://attacker.example/", "jti-#{i}"), expires_at: far_future)).to be true
      end

      expect(guard.first_use?(key_for("victim", "captured"), expires_at: far_future)).to be false
    end

    it "never refuses a legitimate busy client, trimming its own oldest entries instead" do
      6.times do |i|
        expect(guard.first_use?(key_for("busy", "jti-#{i}"), expires_at: far_future)).to be true
      end

      expect(guard.first_use?(key_for("busy", "jti-0"), expires_at: far_future)).to be true
      expect(guard.first_use?(key_for("busy", "jti-5"), expires_at: far_future)).to be false
    end

    it "makes a client over the threshold pay with its own oldest, not the oldest overall" do
      stub_const("#{described_class}::FLOOD_THRESHOLD", 2)

      expect(guard.first_use?(key_for("first", "only"), expires_at: far_future)).to be true
      expect(guard.first_use?(key_for("busy", "a"), expires_at: far_future)).to be true
      expect(guard.first_use?(key_for("busy", "b"), expires_at: far_future)).to be true
      expect(guard.first_use?(key_for("busy", "c"), expires_at: far_future)).to be true

      # Full. "busy" arrives holding three entries, so its own oldest goes —
      # not "first"'s, although that is the oldest entry overall.
      expect(guard.first_use?(key_for("busy", "d"), expires_at: far_future)).to be true
      expect(guard.first_use?(key_for("first", "only"), expires_at: far_future)).to be false
      expect(guard.first_use?(key_for("busy", "a"), expires_at: far_future)).to be true
    end
  end

  # A busy honest client may legitimately hold more than FLOOD_THRESHOLD
  # live assertions. Were eviction to single out whichever client holds the
  # most entries, an attacker could fill the guard with one-entry clients
  # and have every further arrival drain that client's live replay records
  # while the attacker's own older entries stay put — making its captured
  # assertions replayable. Eviction therefore only ever charges the client
  # presenting the new assertion, and otherwise stays plain FIFO.
  context "when a busy honest client shares the guard with a spread-out flood" do
    before do
      stub_const("#{described_class}::MAX_ENTRIES", 6)
      stub_const("#{described_class}::FLOOD_THRESHOLD", 2)
    end

    it "does not drain the largest client's records while older entries remain" do
      expect(guard.first_use?(key_for("https://attacker.example/1", "x"), expires_at: far_future)).to be true
      expect(guard.first_use?(key_for("busy", "a"), expires_at: far_future)).to be true
      expect(guard.first_use?(key_for("busy", "b"), expires_at: far_future)).to be true
      expect(guard.first_use?(key_for("busy", "c"), expires_at: far_future)).to be true
      expect(guard.first_use?(key_for("https://attacker.example/2", "x"), expires_at: far_future)).to be true
      expect(guard.first_use?(key_for("https://attacker.example/3", "x"), expires_at: far_future)).to be true

      # Full. "busy" is the largest partition and over the threshold, but the
      # arrival is a fresh one-entry client, so the oldest entry overall goes
      # — the attacker's own first — and "busy"'s records stay live.
      expect(guard.first_use?(key_for("https://attacker.example/4", "x"), expires_at: far_future)).to be true
      expect(guard.first_use?(key_for("busy", "a"), expires_at: far_future)).to be false
      expect(guard.first_use?(key_for("https://attacker.example/1", "x"), expires_at: far_future)).to be true
    end
  end

  # A flooder can spread its assertions across as many client_ids as it
  # likes (one document per path on one host), so no client then stands out
  # as the flood. Picking the largest partition regardless would hand it the
  # busiest honest client to drain; the guard falls back to plain FIFO
  # instead, which costs that client no more than before.
  context "when the flood is spread thin across many clients" do
    before do
      stub_const("#{described_class}::MAX_ENTRIES", 4)
      stub_const("#{described_class}::FLOOD_THRESHOLD", 2)
    end

    it "evicts the oldest entry overall rather than the busiest client's" do
      expect(guard.first_use?(key_for("https://attacker.example/1", "x"), expires_at: far_future)).to be true
      expect(guard.first_use?(key_for("honest", "a"), expires_at: far_future)).to be true
      expect(guard.first_use?(key_for("honest", "b"), expires_at: far_future)).to be true
      expect(guard.first_use?(key_for("https://attacker.example/2", "x"), expires_at: far_future)).to be true

      # Full. "honest" is the largest partition but within the threshold, so
      # the oldest entry overall — the attacker's first — goes.
      expect(guard.first_use?(key_for("https://attacker.example/3", "x"), expires_at: far_future)).to be true
      expect(guard.first_use?(key_for("honest", "a"), expires_at: far_future)).to be false
      expect(guard.first_use?(key_for("honest", "b"), expires_at: far_future)).to be false
      expect(guard.first_use?(key_for("https://attacker.example/1", "x"), expires_at: far_future)).to be true
    end
  end

  # URL client_ids can be minted by anyone once Client ID Metadata Documents
  # are enabled — one document per path on one host — and authentication runs
  # before grant validation, so filling the guard with valid assertions from
  # many one-entry URL clients is cheap. Whatever such a flood evicts, it
  # must never be the live replay record of a registered client: that would
  # make a captured registered-client assertion reusable before its exp.
  context "when URL clients meet registered clients in a full guard" do
    before do
      stub_const("#{described_class}::MAX_ENTRIES", 4)
      stub_const("#{described_class}::FLOOD_THRESHOLD", 2)
    end

    it "never evicts a registered client's record for a URL arrival" do
      expect(guard.first_use?(key_for("registered", "captured"), expires_at: far_future)).to be true

      10.times do |i|
        guard.first_use?(url_key_for("https://attacker.example/#{i}", "x"), expires_at: far_future)
      end

      expect(guard.first_use?(key_for("registered", "captured"), expires_at: far_future)).to be false
    end

    # The pools are accounted separately, so registered traffic filling its
    # own pool leaves the URL pool untouched and document clients keep being
    # remembered. Coupling the two would have a single busy registered client
    # lock every document client out of this worker until its entries expire,
    # which MAX_LIFETIME lets it push out to an hour.
    it "still admits a URL arrival when the registered pool is full" do
      4.times do |i|
        expect(guard.first_use?(key_for("registered-#{i}", "jti"), expires_at: far_future)).to be true
      end

      expect(guard.first_use?(url_key_for("https://a.example/c", "jti"), expires_at: far_future)).to be true

      # ...and the registered records all stay live.
      4.times do |i|
        expect(guard.first_use?(key_for("registered-#{i}", "jti"), expires_at: far_future)).to be false
      end
    end

    # A registered application may hold an https:// uid (a pre-registered
    # Client Identifier URL, draft Section 7.2), and with the feature off
    # every https:// uid is one. PrivateKeyJwt builds such a client's key
    # without the URL-pool mark, and the guard goes by the mark, not by the
    # shape: its live record is no more a URL flood's to evict than any other
    # registered client's, and its own arrival is never the one refused.
    it "keeps a registered client's https uid out of the URL pool" do
      expect(guard.first_use?(key_for("https://registered.example/c", "captured"), expires_at: far_future)).to be true

      10.times do |i|
        guard.first_use?(url_key_for("https://attacker.example/#{i}", "x"), expires_at: far_future)
      end

      expect(guard.first_use?(key_for("https://registered.example/c", "captured"), expires_at: far_future)).to be false
    end

    it "does not refuse a registered client's https uid in a guard full of registered entries" do
      4.times { |i| guard.first_use?(key_for("registered-#{i}", "jti"), expires_at: far_future) }

      expect(guard.first_use?(key_for("https://registered.example/c", "jti"), expires_at: far_future)).to be true
    end

    # The letter of the rule above is not enough on its own: with one shared
    # budget, a URL flood arriving after a registered client's record would
    # make that record the oldest overall and have the next registered
    # arrival do the flood's work for it. Separate pools mean the flood never
    # counts against the registered side at all.
    it "does not let a URL flood set up a registered arrival to evict a registered record" do
      expect(guard.first_use?(key_for("victim", "captured"), expires_at: far_future)).to be true
      3.times { |i| guard.first_use?(url_key_for("https://attacker.example/#{i}", "x"), expires_at: far_future) }

      # An unrelated registered client arrives; the URL entries were never
      # its pool's to be crowded by.
      expect(guard.first_use?(key_for("honest", "jti"), expires_at: far_future)).to be true
      expect(guard.first_use?(key_for("victim", "captured"), expires_at: far_future)).to be false
    end

    it "lets a registered arrival evict the oldest entry overall once no URL entry is left" do
      4.times { |i| expect(guard.first_use?(key_for("registered-#{i}", "jti"), expires_at: far_future)).to be true }

      expect(guard.first_use?(key_for("newcomer", "jti"), expires_at: far_future)).to be true
      expect(guard.first_use?(key_for("registered-0", "jti"), expires_at: far_future)).to be true
    end

    # Each pool is a plain FIFO within itself: a registered arrival into a
    # full registered pool takes the oldest registered entry and leaves every
    # URL entry where it is.
    it "lets a registered arrival evict the oldest entry of its own pool" do
      guard.first_use?(url_key_for("https://a.example/c", "old"), expires_at: far_future)
      4.times { |i| expect(guard.first_use?(key_for("registered-#{i}", "jti"), expires_at: far_future)).to be true }

      expect(guard.first_use?(key_for("newcomer", "jti"), expires_at: far_future)).to be true
      # The oldest registered entry went; the URL entry did not.
      expect(guard.first_use?(key_for("registered-0", "jti"), expires_at: far_future)).to be true
      expect(guard.first_use?(url_key_for("https://a.example/c", "old"), expires_at: far_future)).to be false
    end

    # The branch that makes a single self-flooding document client trim its
    # own records rather than another document client's.
    it "makes one document client above the threshold pay with its own oldest" do
      expect(guard.first_use?(url_key_for("https://other.example/c", "live"), expires_at: far_future)).to be true
      3.times { |i| guard.first_use?(url_key_for("https://flood.example/c", "jti-#{i}"), expires_at: far_future) }

      expect(guard.first_use?(url_key_for("https://flood.example/c", "jti-3"), expires_at: far_future)).to be true
      expect(guard.first_use?(url_key_for("https://other.example/c", "live"), expires_at: far_future)).to be false
      expect(guard.first_use?(url_key_for("https://flood.example/c", "jti-0"), expires_at: far_future)).to be true
    end
  end

  context "when kept full by unexpired assertions" do
    before do
      stub_const("#{described_class}::MAX_ENTRIES", 2)
      stub_const("#{described_class}::FLOOD_THRESHOLD", 0)
    end

    # Observed through an expired entry: a sweep would prune it, eviction
    # leaves it alone until it is the oldest.
    it "sweeps at most once a second rather than on every authentication" do
      now = Time.now.to_i
      allow(Time).to receive(:now).and_return(Time.at(now).utc)

      guard.first_use?(key_for("client", "a"), expires_at: now - 1)
      guard.first_use?(key_for("client", "b"), expires_at: now + 600)
      # Full: the one sweep this second prunes "a" and makes room.
      expect(guard.first_use?(key_for("client", "c"), expires_at: now + 600)).to be true
      # Full again; no sweep is due, so "b" is evicted for the expired "d".
      guard.first_use?(key_for("client", "d"), expires_at: now - 1)
      # And again: were a sweep run, "d" would be pruned here.
      guard.first_use?(key_for("client", "e"), expires_at: now + 600)

      expect(guard.first_use?(key_for("client", "d"), expires_at: now + 600)).to be false
    end
  end
end
