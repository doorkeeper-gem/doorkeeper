# frozen_string_literal: true

require "spec_helper"

RSpec.describe Doorkeeper::Server do
  subject(:server) do
    described_class.new(context)
  end

  let(:fake_class) { double :fake_class }
  let(:context) { double :context }

  describe ".authorization_request" do
    it "raises error when strategy does not match phase" do
      expect do
        server.token_request(:code)
      end.to raise_error(Doorkeeper::Errors::InvalidTokenStrategy)
    end

    context "when only Authorization Code strategy is enabled" do
      before do
        allow(Doorkeeper.configuration)
          .to receive(:grant_flows)
          .and_return(["authorization_code"])
      end

      it "raises error when using the disabled Client Credentials strategy" do
        expect do
          server.token_request(:client_credentials)
        end.to raise_error(Doorkeeper::Errors::InvalidTokenStrategy)
      end
    end

    it "builds the request with the strategy the registered flow declares" do
      expect(server.authorization_request("code")).to be_a(Doorkeeper::Request::Code)
    end

    it "accepts a symbol response type" do
      expect(server.authorization_request(:code)).to be_a(Doorkeeper::Request::Code)
    end

    it "builds the request with composite strategy name" do
      Doorkeeper::GrantFlow.register(
        "id_token token",
        response_type_matches: "id_token token",
        response_type_strategy: fake_class,
      )

      Doorkeeper.configure do
        orm DOORKEEPER_ORM
        grant_flows ["id_token token"]
      end

      expect(fake_class).to receive(:new).with(server)
      server.authorization_request "id_token token"
    ensure
      Doorkeeper::GrantFlow::Registry.flows.delete(:"id_token token")
    end

    it "builds the request with a composite strategy registered through the deprecated hook" do
      Doorkeeper.configure { orm DOORKEEPER_ORM }
      allow(Doorkeeper.config)
        .to receive(:calculate_authorization_response_types)
        .and_return(["id_token token"])

      stub_const "Doorkeeper::Request::IdTokenToken", fake_class
      expect(fake_class).to receive(:new).with(server)
      allow(::Kernel).to receive(:warn)

      server.authorization_request "id_token token"
    end

    # A response_type no registered authorization flow handles must not be
    # resolved through the `constantize` fallback: the deny path of the
    # authorization endpoint reaches this without any prior validation.
    it "raises InvalidTokenStrategy for a response type no flow handles" do
      expect { server.authorization_request "password" }
        .to raise_error(Doorkeeper::Errors::InvalidTokenStrategy)
    end
  end
end
