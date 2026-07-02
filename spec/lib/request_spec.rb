# frozen_string_literal: true

require "spec_helper"

RSpec.describe Doorkeeper::Request do
  describe ".client_authentication_method" do
    subject(:strategy) { described_class.client_authentication_method(request) }

    context "with an HTTP Basic authorization header" do
      let(:request) do
        mock_request(authorization: "Basic #{Base64.strict_encode64("id:secret")}")
      end

      it "selects the client_secret_basic strategy (unwrapped from its Method)" do
        expect(strategy).to eq(Doorkeeper::OAuth::ClientAuthentication::ClientSecretBasic)
      end
    end

    context "with client credentials in the request body" do
      let(:request) do
        mock_request(request_parameters: { client_id: "id", client_secret: "secret" })
      end

      it "selects the client_secret_post strategy" do
        expect(strategy).to eq(Doorkeeper::OAuth::ClientAuthentication::ClientSecretPost)
      end
    end

    context "with only a client_id in the body of a POST (public client)" do
      let(:request) { mock_request(request_parameters: { client_id: "id" }) }

      it "selects the none strategy" do
        expect(strategy).to eq(Doorkeeper::OAuth::ClientAuthentication::None)
      end
    end

    context "when no configured method matches the request" do
      let(:request) { mock_request(request_method: "GET") }

      it "falls back to the FallbackMethod (authenticates to no credentials)" do
        expect(strategy).to eq(Doorkeeper::ClientAuthentication::FallbackMethod)
        expect(strategy.authenticate(request)).to be_nil
      end
    end
  end
end
