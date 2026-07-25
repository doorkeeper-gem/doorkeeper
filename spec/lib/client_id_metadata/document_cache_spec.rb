# frozen_string_literal: true

require "spec_helper"

# DocumentCache#fetch has no default-value argument, so the Hash#fetch cop's
# suggested rewrite does not apply here.
# rubocop:disable Style/RedundantFetchBlock
RSpec.describe Doorkeeper::ClientIdMetadata::DocumentCache do
  subject(:cache) { described_class.new }

  let(:url) { "https://client.example.com/oauth-client" }

  describe "#fetch" do
    it "stores and returns the block result" do
      expect(cache.fetch(url) { :document }).to eq(:document)
    end

    it "memoizes within the TTL" do
      calls = 0
      2.times { cache.fetch(url) { calls += 1 } }

      expect(calls).to eq(1)
    end

    it "does not cache nil results" do
      cache.fetch(url) { nil }
      expect(cache.fetch(url) { :second }).to eq(:second)
    end

    it "does not cache raised failures" do
      expect { cache.fetch(url) { raise "boom" } }.to raise_error("boom")
      expect(cache.fetch(url) { :after_failure }).to eq(:after_failure)
    end

    it "expires entries after the TTL" do
      expired = described_class.new(ttl: 0)
      expired.fetch(url) { :first }

      expect(expired.fetch(url) { :second }).to eq(:second)
    end

    it "keeps distinct URLs separate" do
      cache.fetch(url) { :one }
      expect(cache.fetch("#{url}-2") { :two }).to eq(:two)
    end

    it "bounds the number of stored entries" do
      (described_class::MAX_ENTRIES + 10).times do |i|
        cache.fetch("https://client.example.com/c#{i}") { i }
      end

      expect(cache.fetch("https://client.example.com/c0") { :refetched }).to eq(:refetched)
    end
  end

  describe "#clear" do
    it "drops all entries" do
      cache.fetch(url) { :first }
      cache.clear

      expect(cache.fetch(url) { :second }).to eq(:second)
    end
  end
end
# rubocop:enable Style/RedundantFetchBlock
