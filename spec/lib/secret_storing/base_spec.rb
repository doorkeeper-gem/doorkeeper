# frozen_string_literal: true

require "spec_helper"

RSpec.describe ::Doorkeeper::SecretStoring::Base do
  let(:instance) { double("instance", token: "foo") }

  describe "#transform_secret" do
    it "raises" do
      expect { described_class.transform_secret("foo") }
        .to raise_error(NotImplementedError)
    end
  end

  describe "#store_secret" do
    it "sends to response of #transform_secret to the instance" do
      expect(described_class)
        .to receive(:transform_secret).with("bar")
        .and_return "bar+transform"

      expect(instance).to receive(:token=).with "bar+transform"
      result = described_class.store_secret instance, :token, "bar"
      expect(result).to eq "bar+transform"
    end
  end

  describe "#restore_secret" do
    it "raises" do
      expect { described_class.restore_secret(described_class, :token) }
        .to raise_error(NotImplementedError)
    end
  end

  describe "#allows_restoring_secrets?" do
    it "does not allow it" do
      expect(described_class.allows_restoring_secrets?).to eq false
    end
  end

  describe "validate_for" do
    it "allows for valid model" do
      expect(described_class.validate_for(:application)).to eq true
      expect(described_class.validate_for(:token)).to eq true
    end

    it "raises for invalid model" do
      expect { described_class.validate_for(:wat) }
        .to raise_error(ArgumentError, /can not be used for wat/)
    end
  end

  describe "secret_matches?" do
    before do
      allow(described_class).to receive(:transform_secret) { |input| "transformed: #{input}" }
    end

    it "compares input with #transform_secret" do
      expect(described_class.secret_matches?("input", "input")).to eq false
      expect(described_class.secret_matches?("a", "transformed: a")).to eq true
    end
  end
end
