# frozen_string_literal: true

require "spec_helper"

module Doorkeeper::OAuth
  describe ErrorResponseTypeRequest do
    subject do
      ErrorResponseTypeRequest.new(pre_auth)
    end

    context "when pre_auth error is invalid_request type" do
      let(:pre_auth) { double(error: :invalid_request) }

      it "does not create grant and return InvalidRequestResponse" do
        expect { subject.authorize }.not_to(change { Doorkeeper::AccessGrant.count })
        expect(subject.authorize).to be_an_instance_of(InvalidRequestResponse)
      end
    end

    context "when pre_auth error is not invalid_request type" do
      let(:pre_auth) { double(error: :some_error) }

      it "does not create grant and returns a error_response" do
        expect { subject.authorize }.not_to(change { Doorkeeper::AccessGrant.count })
        expect(subject.authorize).to be_an_instance_of(ErrorResponse)
      end
    end
  end
end
