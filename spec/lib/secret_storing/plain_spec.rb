# frozen_string_literal: true

require "spec_helper"

RSpec.describe ::Doorkeeper::SecretStoring::Plain do
  subject { described_class }

  let(:instance) { double("instance", token: "foo") }

  describe "#transform_secret" do
    it "raises" do
      expect(subject.transform_secret("foo")).to eq "foo"
    end
  end

  describe "#restore_secret" do
    it "raises" do
      expect(subject.restore_secret(instance, :token)).to eq "foo"
    end
  end

  describe "#allows_restoring_secrets?" do
    it "does allow it" do
      expect(subject.allows_restoring_secrets?).to eq true
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
    it "compares input with #transform_secret" do
      expect(subject.secret_matches?("input", "input")).to eq true
      expect(subject.secret_matches?("a", "b")).to eq false
    end
  end
end
