# frozen_string_literal: true

require "spec_helper"

describe ::Doorkeeper::SecretStoring::Base do
  let(:instance) { double("instance", token: "foo") }
  subject { described_class }

  describe "#transform_secret" do
    it "raises" do
      expect { subject.transform_secret("foo") }.to raise_error(NotImplementedError)
    end
  end

  describe "#store_secret" do
    it "sends to response of #transform_secret to the instance" do
      expect(described_class)
        .to receive(:transform_secret).with("bar")
        .and_return "bar+transform"

      expect(instance).to receive(:token=).with "bar+transform"
      result = subject.store_secret instance, :token, "bar"
      expect(result).to eq "bar+transform"
    end
  end

  describe "#restore_secret" do
    it "raises" do
      expect { subject.restore_secret(subject, :token) }.to raise_error(NotImplementedError)
    end
  end

  describe "#allows_restoring_secrets?" do
    it "does not allow it" do
      expect(subject.allows_restoring_secrets?).to eq false
    end
  end

  describe "validate_for" do
    it "allows for valid model" do
      expect(subject.validate_for(:application)).to eq true
      expect(subject.validate_for(:token)).to eq true
    end

    it "raises for invalid model" do
      expect { subject.validate_for(:wat) }.to raise_error(ArgumentError, /can not be used for wat/)
    end
  end

  describe "secret_matches?" do
    before do
      allow(subject).to receive(:transform_secret) { |input| "transformed: #{input}" }
    end

    it "compares input with #transform_secret" do
      expect(subject.secret_matches?("input", "input")).to eq false
      expect(subject.secret_matches?("a", "transformed: a")).to eq true
    end
  end
end
