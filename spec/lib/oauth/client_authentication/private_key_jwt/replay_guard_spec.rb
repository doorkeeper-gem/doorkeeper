# frozen_string_literal: true

require "spec_helper"

RSpec.describe Doorkeeper::OAuth::ClientAuthentication::PrivateKeyJwt::ReplayGuard do
  subject(:guard) { described_class.instance }

  let(:far_future) { Time.now.to_i + 600 }

  def key_for(client_id, jti)
    "#{client_id.length}:#{client_id}:#{jti}"
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

    it "treats a key in any other shape as its own partition" do
      expect(described_class.partition_of("opaque")).to eq("opaque")
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

    it "evicts from the client standing out as the flood, not the oldest entry overall" do
      expect(guard.first_use?(key_for("first", "only"), expires_at: far_future)).to be true
      expect(guard.first_use?(key_for("second", "a"), expires_at: far_future)).to be true
      expect(guard.first_use?(key_for("second", "b"), expires_at: far_future)).to be true
      expect(guard.first_use?(key_for("second", "c"), expires_at: far_future)).to be true

      # Full. "second" holds three entries, so its oldest goes, not "first"'s.
      expect(guard.first_use?(key_for("third", "new"), expires_at: far_future)).to be true
      expect(guard.first_use?(key_for("first", "only"), expires_at: far_future)).to be false
      expect(guard.first_use?(key_for("second", "a"), expires_at: far_future)).to be true
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
