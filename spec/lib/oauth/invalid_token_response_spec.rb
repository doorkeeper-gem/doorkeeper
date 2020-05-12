# frozen_string_literal: true

require "spec_helper"

RSpec.describe Doorkeeper::OAuth::InvalidTokenResponse do
  describe "#name" do
    it { expect(subject.name).to eq(:invalid_token) }
  end

  describe "#status" do
    it { expect(subject.status).to eq(:unauthorized) }
  end

  describe ".from_access_token" do
    let(:response) { described_class.from_access_token(access_token) }

    context "when token revoked" do
      let(:access_token) { double(revoked?: true, expired?: true) }

      it "sets a description" do
        expect(response.description).to include("revoked")
      end

      it "sets the reason" do
        expect(response.reason).to eq(:revoked)
      end
    end

    context "when token expired" do
      let(:access_token) { double(revoked?: false, expired?: true) }

      it "sets a description" do
        expect(response.description).to include("expired")
      end

      it "sets the reason" do
        expect(response.reason).to eq(:expired)
      end
    end

    context "when unknown" do
      let(:access_token) { double(revoked?: false, expired?: false) }

      it "sets a description" do
        expect(response.description).to include("invalid")
      end

      it "sets the reason" do
        expect(response.reason).to eq(:unknown)
      end
    end
  end
end
