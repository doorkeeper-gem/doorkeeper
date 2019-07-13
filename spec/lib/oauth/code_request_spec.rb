# frozen_string_literal: true

require "spec_helper"

module Doorkeeper::OAuth
  describe CodeRequest do
    let(:pre_auth) do
      double(
        :pre_auth,
        client: double(:application, id: 9990),
        redirect_uri: "http://tst.com/cb",
        scopes: nil,
        state: nil,
        error: nil,
        authorizable?: true,
        code_challenge: nil,
        code_challenge_method: nil
      )
    end

    let(:owner) { double :owner, id: 8900 }

    subject do
      CodeRequest.new(pre_auth, owner)
    end

    context "when pre_auth is authorizable" do
      it "creates an access grant and returns a code response" do
        expect { subject.authorize }.to change { Doorkeeper::AccessGrant.count }.by(1)
        expect(subject.authorize).to be_a(CodeResponse)
      end
    end

    context "when pre_auth is not authorizable" do
      before { allow(pre_auth).to receive(:authorizable?).and_return(false) }

      context "with invalid_request error" do
        before { allow(pre_auth).to receive(:error).and_return(:invalid_request) }

        it "does not create grant and returns InvalidRequestResponse" do
          expect { subject.authorize }.not_to(change { Doorkeeper::AccessGrant.count })
          expect(subject.authorize).to be_an_instance_of(InvalidRequestResponse)
        end
      end

      context "with error other than invalid_request" do
        before { allow(pre_auth).to receive(:error).and_return(:some_error) }

        it "does not create grant and returns ErrorResponse" do
          expect { subject.authorize }.not_to(change { Doorkeeper::AccessGrant.count })
          expect(subject.authorize).to be_an_instance_of(ErrorResponse)
        end
      end
    end
  end
end
