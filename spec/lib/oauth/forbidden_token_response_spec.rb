# frozen_string_literal: true

require "spec_helper"

RSpec.describe Doorkeeper::OAuth::ForbiddenTokenResponse do
  describe "#name" do
    it { expect(subject.name).to eq(:invalid_scope) }
  end

  describe "#status" do
    it { expect(subject.status).to eq(:forbidden) }
  end

  describe ".from_scopes" do
    it "have a list of acceptable scopes" do
      response = described_class.from_scopes(["public"])
      expect(response.description).to include("public")
    end
  end
end
