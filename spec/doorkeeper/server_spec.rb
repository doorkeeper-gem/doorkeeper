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

    it "builds the request with selected strategy" do
      stub_const "Doorkeeper::Request::Code", fake_class
      expect(fake_class).to receive(:new).with(server)
      expect(::Kernel).to receive(:warn)
      server.authorization_request :code
    end

    it "builds the request with composite strategy name" do
      Doorkeeper.configure do
        grant_flows ["id_token token"]
      end

      stub_const "Doorkeeper::Request::IdTokenToken", fake_class
      expect(fake_class).to receive(:new).with(server)
      expect(::Kernel).to receive(:warn)
      server.authorization_request "id_token token"
    end
  end

  # Callers that must know *how* a client authenticated read it off the
  # credentials, so the selected method has to be recorded on the way out.
  describe "#credentials" do
    let(:context) { double :context, request: request }

    it "records the IANA name of the method that produced them" do
      request = mock_request(
        authorization: ActionController::HttpAuthentication::Basic.encode_credentials("uid", "secret"),
      )
      server = described_class.new(double(:context, request: request))

      expect(server.credentials.authenticated_with).to eq("client_secret_basic")
    end

    it "records the none method for a public client identifying itself" do
      request = mock_request(request_parameters: { client_id: "uid" })
      server = described_class.new(double(:context, request: request))

      expect(server.credentials.authenticated_with).to eq("none")
    end

    it "keeps a name the strategy set itself" do
      strategy = Class.new do
        def self.matches_request?(_request) = true

        def self.auth_method_name = "registry_name"

        def self.authenticate(_request)
          Doorkeeper::ClientAuthentication::VerifiedCredentials.new("uid", authenticated_with: "own_name")
        end
      end
      allow(Doorkeeper::Request).to receive(:client_authentication_method).and_return(strategy)
      server = described_class.new(double(:context, request: mock_request))

      expect(server.credentials.authenticated_with).to eq("own_name")
    end

    it "leaves the name nil when the strategy declares none" do
      strategy = Class.new do
        def self.matches_request?(_request) = true

        def self.authenticate(_request)
          Doorkeeper::ClientAuthentication::Credentials.new("uid", "secret")
        end
      end
      allow(Doorkeeper::Request).to receive(:client_authentication_method).and_return(strategy)
      server = described_class.new(double(:context, request: mock_request))

      expect(server.credentials.authenticated_with).to be_nil
    end

    it "returns nil when no method authenticates the request" do
      server = described_class.new(double(:context, request: mock_request))

      expect(server.credentials).to be_nil
    end
  end
end
