# frozen_string_literal: true

require "spec_helper"

RSpec.describe Doorkeeper::OAuth::ClientAuthentication::PrivateKeyJwt::ReplayGuard do
  subject(:guard) { described_class.instance }

  let(:expires_at) { Time.now.to_i + 60 }

  before { guard.clear }

  after { guard.clear }

  it "remembers a key until it expires" do
    expect(guard.first_use?("jti-1", expires_at: expires_at)).to be true
    expect(guard.first_use?("jti-1", expires_at: expires_at)).to be false

    Timecop.freeze(Time.at(expires_at).utc) do
      expect(guard.first_use?("jti-1", expires_at: expires_at + 60)).to be true
    end
  end

  # When the guard is full even after expired entries have been pruned, the
  # oldest entries are evicted rather than new assertions rejected: rejecting
  # would let a flood of assertions lock legitimate clients out entirely.
  it "evicts the oldest entries instead of rejecting new keys when full" do
    stub_const("#{described_class}::MAX_ENTRIES", 2)

    expect(guard.first_use?("jti-1", expires_at: expires_at)).to be true
    expect(guard.first_use?("jti-2", expires_at: expires_at)).to be true
    expect(guard.first_use?("jti-3", expires_at: expires_at)).to be true

    # The newest key is still remembered ...
    expect(guard.first_use?("jti-3", expires_at: expires_at)).to be false
    # ... while the oldest one was evicted to make room for it.
    expect(guard.first_use?("jti-1", expires_at: expires_at)).to be true
  end
end
