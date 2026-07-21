# frozen_string_literal: true

require "spec_helper"

RSpec.describe Doorkeeper::OAuth::Hooks::Context do
  describe "#initialize" do
    it "assigns known attributes and ignores unknown ones" do
      auth = double
      context = described_class.new(auth: auth, pre_auth: "pre_auth", unknown: "ignored")

      expect(context.auth).to eq(auth)
      expect(context.pre_auth).to eq("pre_auth")
    end
  end

  describe "#issued_token" do
    it "delegates to auth" do
      auth = double(issued_token: "issued token")

      expect(described_class.new(auth: auth).issued_token).to eq("issued token")
    end

    it "returns nil when there is no auth" do
      expect(described_class.new.issued_token).to be_nil
    end
  end
end
