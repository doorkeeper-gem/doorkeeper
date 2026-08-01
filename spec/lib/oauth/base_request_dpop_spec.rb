# frozen_string_literal: true

require "spec_helper"

RSpec.describe Doorkeeper::OAuth::BaseRequest do
  describe "a third-party grant flow that subclasses BaseRequest" do
    subject(:request) { Class.new(described_class).new }

    context "when force_dpop is enabled and no proof was injected" do
      before { config_is_set(:force_dpop, true) }

      it "is invalid rather than raising" do
        expect { request.valid? }.not_to raise_error
        expect(request.valid?).to be false
      end

      it "reports invalid_dpop_proof" do
        request.valid?

        expect(request.error).to eq(Doorkeeper::Errors::InvalidDPoPProof)
      end
    end
  end
end
