# frozen_string_literal: true

require "spec_helper"

RSpec.describe Doorkeeper::OAuth::BaseRequest do
  describe "a third-party grant flow that subclasses BaseRequest" do
    subject(:request) { Class.new(described_class).new }

    context "when force_dpop is enabled and no proof was injected" do
      before { config_is_set(:force_dpop, true) }

      it "neither raises nor invalidates the request on its own" do
        expect { request.valid? }.not_to raise_error
        expect(request.valid?).to be true
      end

      it "raises assembling dpop token attributes without a dpop binding" do
        expect { request.send(:dpop_token_attributes) }
          .to raise_error(Doorkeeper::Errors::InvalidDPoPProof) do |error|
            expect(error.response.name).to eq(:invalid_dpop_proof)
            expect(error.response.status).to eq(:bad_request)
          end
      end
    end

    context "when force_dpop is enabled, the request had no dpop binding, but the grant has a dpop binding" do
      subject(:request) do
        Class.new(described_class) do
          def dpop_token_attributes
            super(fallback_dpop_jkt: "thumbprint")
          end
        end.new
      end

      before { config_is_set(:force_dpop, true) }

      it "uses the existing binding" do
        expect(request.send(:dpop_token_attributes)).to eq(dpop_jkt: "thumbprint")
      end
    end
  end
end
