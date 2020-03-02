# frozen_string_literal: true

require "spec_helper"

describe "Reusable" do
  subject do
    Class.new do
      include Doorkeeper::Models::Reusable
    end.new
  end

  describe :reusable? do
    it "is reusable if its expires_in is nil" do
      allow(subject).to receive(:expired?).and_return(false)
      allow(subject).to receive(:expires_in).and_return(nil)
      expect(subject).to be_reusable
    end

    it "is reusable if its expiry has crossed reusable limit" do
      allow(subject).to receive(:expired?).and_return(false)
      allow(Doorkeeper.configuration).to receive(:token_reuse_limit).and_return(90)
      allow(subject).to receive(:expires_in).and_return(100.seconds)
      allow(subject).to receive(:expires_in_seconds).and_return(20.seconds)
      expect(subject).to be_reusable
    end

    it "is not reusable if its expiry has crossed reusable limit" do
      allow(subject).to receive(:expired?).and_return(false)
      allow(Doorkeeper.configuration).to receive(:token_reuse_limit).and_return(90)
      allow(subject).to receive(:expires_in).and_return(100.seconds)
      allow(subject).to receive(:expires_in_seconds).and_return(5.seconds)
      expect(subject).not_to be_reusable
    end

    it "is not reusable if it is already expired" do
      allow(subject).to receive(:expired?).and_return(true)
      expect(subject).not_to be_reusable
    end
  end
end
