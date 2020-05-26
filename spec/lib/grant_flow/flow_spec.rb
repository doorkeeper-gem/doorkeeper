# frozen_string_literal: true

require "spec_helper"

RSpec.describe Doorkeeper::GrantFlow::Flow do
  subject(:flow) { described_class.new(name, **options) }

  let(:name) { "secret_handshake" }
  let(:options) { {} }

  it "reflects the given name" do
    expect(flow.name).to eq name
  end

  context "with neither grant_type nor response_type" do
    it "does not handle grant_type" do
      expect(flow.handles_grant_type?).to be false
    end

    it "does not handle response_type" do
      expect(flow.handles_response_type?).to be false
    end
  end

  context "when given a grant_type to match" do
    let(:grant_type_matches) { "secret_handshake" }
    let(:options) { { grant_type_matches: grant_type_matches } }

    it "handles grant_type" do
      expect(flow.handles_grant_type?).to be true
    end

    context "when grant_type_matches is a string" do
      it "matches grant_type values" do
        expect(flow.matches_grant_type?(grant_type_matches)).to be true
      end
    end

    context "when grant_type_matches is a regular expression" do
      let(:grant_type_matches) { /^secret_(.*)$/ }

      it "matches grant_type values" do
        expect(flow.matches_grant_type?("secret_boogie")).to be true
      end
    end
  end

  context "when given a response_type to match" do
    let(:response_type_matches) { "secret_handshake" }
    let(:options) { { response_type_matches: response_type_matches } }

    it "handles response_type" do
      expect(flow.handles_response_type?).to be true
    end

    context "when response_type_matches is a string" do
      it "matches response_type values" do
        expect(flow.matches_response_type?(response_type_matches)).to be true
      end
    end

    context "when response_type_matches is a regular expression" do
      let(:response_type_matches) { /^secret_(.*)$/ }

      it "matches response_type values" do
        expect(flow.matches_response_type?("secret_boogie")).to be true
      end
    end
  end
end
