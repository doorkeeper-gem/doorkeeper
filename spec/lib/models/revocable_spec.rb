# frozen_string_literal: true

require "spec_helper"

RSpec.describe Doorkeeper::Models::Revocable do
  subject(:fake_object) do
    Class.new do
      include Doorkeeper::Models::Revocable
    end.new
  end

  describe "#revoke" do
    let(:revoked_at) { nil }

    before do
      allow(fake_object).to receive(:revoked_at).and_return(revoked_at)
    end

    it "updates :revoked_at attribute with current time" do
      utc = double utc: double
      clock = double now: utc
      expect(fake_object).to receive(:update_attribute).with(:revoked_at, clock.now.utc)
      fake_object.revoke(clock)
    end

    context "when the object is already revoked" do
      let(:revoked_at) { Time.now.utc - 1000 }

      it "does not update :revoked_at attribute" do
        expect(fake_object).not_to receive(:update_attribute)
      end
    end
  end

  describe "#revoked?" do
    it "is revoked if :revoked_at has passed" do
      allow(fake_object).to receive(:revoked_at).and_return(Time.now.utc - 1000)
      expect(fake_object).to be_revoked
    end

    it "is not revoked if :revoked_at has not passed" do
      allow(fake_object).to receive(:revoked_at).and_return(Time.now.utc + 1000)
      expect(fake_object).not_to be_revoked
    end

    it "is not revoked if :revoked_at is not set" do
      allow(fake_object).to receive(:revoked_at).and_return(nil)
      expect(fake_object).not_to be_revoked
    end
  end

  describe "#revoke_previous_refresh_token!" do
    it "revokes the previous token if exists and resets the `previous_refresh_token` attribute" do
      previous_token = FactoryBot.create(
        :access_token,
        refresh_token: "refresh_token",
      )
      current_token = FactoryBot.create(
        :access_token,
        previous_refresh_token: previous_token.refresh_token,
      )

      current_token.revoke_previous_refresh_token!

      expect(current_token.previous_refresh_token).to be_empty
      expect(previous_token.reload).to be_revoked
    end
  end
end
