# frozen_string_literal: true

require "spec_helper"

RSpec.describe Doorkeeper::Server do
  subject(:server) { described_class.new(context) }

  let(:context) { double("controller", request: request) }
  let(:request) do
    instance_double(ActionDispatch::Request, headers: ActionDispatch::Http::Headers.from_hash({}))
  end

  describe "#dpop_proof" do
    context "when dpop is not supported" do
      before do
        allow(Doorkeeper.config.access_token_model).to receive(:dpop_supported?).and_return(false)
      end

      it "does not build a dpop proof, so the optional jwt gem is never required" do
        expect(Doorkeeper::OAuth::DPoPProof).not_to receive(:new)

        expect(server.dpop_proof).to be_nil
      end
    end

    context "when dpop is supported" do
      before do
        allow(Doorkeeper.config.access_token_model).to receive(:dpop_supported?).and_return(true)
      end

      it "builds a dpop proof" do
        expect(server.dpop_proof).to be_a(Doorkeeper::OAuth::DPoPProof)
      end
    end

    context "when dpop is required" do
      before { config_is_set(:force_dpop, true) }

      it "builds a dpop proof" do
        expect(server.dpop_proof).to be_a(Doorkeeper::OAuth::DPoPProof)
      end
    end
  end
end
