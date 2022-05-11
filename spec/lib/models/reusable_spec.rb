# frozen_string_literal: true

require "spec_helper"

RSpec.describe Doorkeeper::Models::Reusable do
  subject(:fake_object) do
    Class.new do
      include Doorkeeper::Models::Configurable
      include Doorkeeper::Models::Reusable
    end.new
  end

  describe "#reusable?" do
    it "is reusable if its expires_in is nil" do
      allow(fake_object).to receive(:expired?).and_return(false)
      allow(fake_object).to receive(:expires_in).and_return(nil)
      expect(fake_object).to be_reusable
    end

    it "is reusable if its expiry has crossed reusable limit" do
      allow(fake_object).to receive(:expired?).and_return(false)
      allow(Doorkeeper.configuration).to receive(:token_reuse_limit).and_return(90)
      allow(fake_object).to receive(:expires_in).and_return(100.seconds)
      allow(fake_object).to receive(:expires_in_seconds).and_return(20.seconds)
      expect(fake_object).to be_reusable
    end

    it "is not reusable if its expiry has crossed reusable limit" do
      allow(fake_object).to receive(:expired?).and_return(false)
      allow(Doorkeeper.configuration).to receive(:token_reuse_limit).and_return(90)
      allow(fake_object).to receive(:expires_in).and_return(100.seconds)
      allow(fake_object).to receive(:expires_in_seconds).and_return(5.seconds)
      expect(fake_object).not_to be_reusable
    end

    it "is not reusable if it is already expired" do
      allow(fake_object).to receive(:expired?).and_return(true)
      expect(fake_object).not_to be_reusable
    end
  end
end
