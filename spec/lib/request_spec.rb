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

    context "with both an HTTP Basic header and client credentials in the body" do
      let(:request) do
        mock_request(
          authorization: "Basic #{Base64.strict_encode64("id:secret")}",
          request_parameters: { client_id: "id", client_secret: "secret" },
        )
      end

      it "raises MultipleClientAuthMethods (RFC 6749 §2.3)" do
        expect { strategy }.to raise_error(Doorkeeper::Errors::MultipleClientAuthMethods)
      end
    end

    context "when no configured method matches the request" do
      let(:request) { mock_request(request_method: "GET") }

      it "falls back to the FallbackMethod (authenticates to no credentials)" do
        expect(strategy).to eq(Doorkeeper::ClientAuthentication::FallbackMethod)
        expect(strategy.authenticate(request)).to be_nil
      end
    end

    context "when a custom body-based method matches alongside :none" do
      let(:client_assertion_method) { double(matches_request?: true, authenticate: nil) }

      let(:request) do
        mock_request(request_parameters: { client_id: "id", client_assertion: "jwt" })
      end

      before do
        @original_methods = Doorkeeper::ClientAuthentication::Registry.registered_methods.deep_dup
        Doorkeeper::ClientAuthentication.register(:client_assertion, client_assertion_method)

        Doorkeeper.configure do
          orm DOORKEEPER_ORM
          client_authentication %i[client_secret_basic client_secret_post none client_assertion]
        end
      end

      after do
        Doorkeeper::ClientAuthentication::Registry.registered_methods = @original_methods
      end

      it "selects the real method instead of counting the bare client_id as a second mechanism" do
        expect(strategy).to eq(client_assertion_method)
      end
    end

    context "when the configuration lists the same method twice" do
      let(:request) do
        mock_request(authorization: "Basic #{Base64.strict_encode64("id:secret")}")
      end

      before do
        Doorkeeper.configure do
          orm DOORKEEPER_ORM
          client_authentication %i[client_secret_basic client_secret_post client_secret_basic]
        end
      end

      it "does not treat the duplicate entry as a second authentication method" do
        expect(strategy).to eq(Doorkeeper::OAuth::ClientAuthentication::ClientSecretBasic)
      end
    end

    context "with a deprecated client_credentials config mixing symbols and a callable" do
      before do
        allow(Kernel).to receive(:warn)
      end

      context "when the callable overlaps a built-in method" do
        let(:request) do
          mock_request(request_parameters: { client_id: "id", client_secret: "secret" })
        end

        before do
          extractor = ->(req) { req.request_parameters.values_at("client_id", "client_secret") }

          Doorkeeper.configure do
            orm DOORKEEPER_ORM
            client_credentials :from_params, extractor
          end
        end

        it "keeps the historical first-extractor-wins behaviour instead of raising" do
          expect(strategy).to eq(Doorkeeper::OAuth::ClientAuthentication::ClientSecretPost)
        end
      end

      context "when an earlier method already matches the request" do
        let(:request) do
          mock_request(authorization: "Basic #{Base64.strict_encode64("id:secret")}")
        end

        let(:extractor_calls) { [] }

        before do
          extractor = lambda do |req|
            extractor_calls << req
            nil
          end

          Doorkeeper.configure do
            orm DOORKEEPER_ORM
            client_credentials :from_basic, extractor
          end
        end

        it "does not invoke a later callable extractor (first match wins)" do
          expect(strategy).to eq(Doorkeeper::OAuth::ClientAuthentication::ClientSecretBasic)
          expect(extractor_calls).to be_empty
        end
      end
    end
  end
end
