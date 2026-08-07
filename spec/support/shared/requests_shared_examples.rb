# frozen_string_literal: true

shared_examples "sender-constraining access_token using dpop" do |when_bearer_token_expected: nil, when_dpop_token_expected: nil|
  context "when using dpop" do
    context "when the dpop proof is valid" do
      let(:dpop_proof) { dpop_proof_double }

      it "issues a dpop token" do
        instance_exec(&when_dpop_token_expected) if when_dpop_token_expected
        request.authorize

        next if when_dpop_token_expected

        issued_token = Doorkeeper::AccessToken.last
        expect(issued_token).to be_uses_dpop
        expect(issued_token.token_type).to eq("DPoP")
        expect(issued_token.dpop_jkt).to eq("jkt_123")
      end
    end

    context "when the dpop proof is invalid" do
      let(:dpop_proof) { dpop_proof_double(valid?: false) }

      it "invalidates the request" do
        request.validate
        expect(request.error).to eq(Doorkeeper::Errors::InvalidDPoPProof)
      end
    end

    context "when dpop is not supported" do
      before { allow(Doorkeeper::AccessToken).to receive(:dpop_supported?).and_return(false) }

      context "when the dpop proof is valid" do
        let(:dpop_proof) { dpop_proof_double }

        it "issues a Bearer token" do
          instance_exec(&when_bearer_token_expected) if when_bearer_token_expected
          request.authorize

          next if when_bearer_token_expected

          issued_token = Doorkeeper::AccessToken.last
          expect(issued_token).not_to be_uses_dpop
          expect(issued_token.token_type).to eq("Bearer")
        end
      end

      context "when the dpop proof is invalid" do
        let(:dpop_proof) { dpop_proof_double(valid?: false) }

        it "validates the request without trying to validate the would be invalid dpop proof" do
          request.validate
          expect(request.error).to be_nil
        end
      end
    end

    context "when dpop is required" do
      before { config_is_set(:force_dpop, true) }

      context "when the dpop proof is blank" do
        let(:dpop_proof) { dpop_proof_double(blank?: true) }

        it "invalidates the request" do
          request.validate
          expect(request.error).to eq(Doorkeeper::Errors::InvalidDPoPProof)
        end
      end
    end
  end
end
