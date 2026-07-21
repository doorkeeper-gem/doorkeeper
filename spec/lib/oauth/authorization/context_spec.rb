# frozen_string_literal: true

require "spec_helper"

RSpec.describe Doorkeeper::OAuth::Authorization::Context do
  describe "#initialize" do
    it "assigns known attributes and ignores unknown ones" do
      context = described_class.new(
        client: "client",
        grant_type: "grant_type",
        scopes: "scopes",
        resource_owner: "owner",
        unknown: "ignored",
      )

      expect(context.client).to eq("client")
      expect(context.grant_type).to eq("grant_type")
      expect(context.scopes).to eq("scopes")
      expect(context.resource_owner).to eq("owner")
    end
  end
end
