# frozen_string_literal: true

require "spec_helper"

RSpec.describe Doorkeeper::OAuth::InvalidRequestResponse do
  subject(:response) { described_class.new }

  describe "#name" do
    it { expect(response.name).to eq(:invalid_request) }
  end

  describe "#status" do
    it { expect(response.status).to eq(:bad_request) }
  end

  describe ".from_request" do
    let(:response) { described_class.from_request(request) }

    context "when param missed" do
      let(:request) { double(missing_param: "some_param") }

      it "sets a description" do
        expect(response.description).to eq(
          I18n.t(:missing_param, scope: %i[doorkeeper errors messages invalid_request], value: "some_param"),
        )
      end

      it "sets the reason" do
        expect(response.reason).to eq(:missing_param)
      end
    end

    context "when server doesn't support PKCE" do
      let(:request) { double(invalid_request_reason: :not_support_pkce) }

      it "sets a description" do
        expect(response.description).to eq(
          I18n.t(:not_support_pkce, scope: %i[doorkeeper errors messages invalid_request]),
        )
      end

      it "sets the reason" do
        expect(response.reason).to eq(:not_support_pkce)
      end
    end

    context "when request is not authorized" do
      let(:request) { double(invalid_request_reason: :request_not_authorized) }

      it "sets a description" do
        expect(response.description).to eq(
          I18n.t(:request_not_authorized, scope: %i[doorkeeper errors messages invalid_request]),
        )
      end

      it "sets the reason" do
        expect(response.reason).to eq(:request_not_authorized)
      end
    end

    context "when unknown reason" do
      let(:request) { double(invalid_request_reason: :unknown_reason) }

      it "sets a description" do
        expect(response.description).to eq(
          I18n.t(:unknown, scope: %i[doorkeeper errors messages invalid_request]),
        )
      end

      it "sets the reason to unknown" do
        expect(response.reason).to eq(:unknown_reason)
      end
    end
  end
end
