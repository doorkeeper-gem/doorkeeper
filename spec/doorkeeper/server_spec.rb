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

    it "overwrites a name the strategy set itself" do
      strategy = Class.new do
        def self.matches_request?(_request) = true

        def self.auth_method_name = "declared_name"

        def self.authenticate(_request)
          Doorkeeper::ClientAuthentication::VerifiedCredentials.new("uid", authenticated_with: "another_name")
        end
      end
      allow(Doorkeeper::Request).to receive(:client_authentication_method).and_return(strategy)
      server = described_class.new(double(:context, request: mock_request))

      expect(server.credentials.authenticated_with).to eq("declared_name")
    end

    # A strategy declaring no name cannot borrow another method's: a client
    # whose document names that method must not be authenticated by this one.
    it "clears a name set by a strategy that declares none" do
      strategy = Class.new do
        def self.matches_request?(_request) = true

        def self.authenticate(_request)
          Doorkeeper::ClientAuthentication::VerifiedCredentials.new("uid", authenticated_with: "private_key_jwt")
        end
      end
      allow(Doorkeeper::Request).to receive(:client_authentication_method).and_return(strategy)
      server = described_class.new(double(:context, request: mock_request))

      expect(server.credentials.authenticated_with).to be_nil
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

    it "records a name a strategy declares as a Symbol as a String" do
      strategy = Class.new do
        def self.matches_request?(_request) = true

        def self.auth_method_name = :tls_client_auth

        def self.authenticate(_request)
          Doorkeeper::ClientAuthentication::VerifiedCredentials.new("uid")
        end
      end
      allow(Doorkeeper::Request).to receive(:client_authentication_method).and_return(strategy)
      server = described_class.new(double(:context, request: mock_request))

      expect(server.credentials.authenticated_with).to eq("tls_client_auth")
    end

    # A host strategy may hand back a frozen value object; that worked before
    # the method's name was recorded here, and must keep working — on a copy,
    # so the record is still the server's.
    it "records the name on a copy of frozen credentials" do
      strategy = Class.new do
        def self.matches_request?(_request) = true

        def self.auth_method_name = "tls_client_auth"

        def self.authenticate(_request)
          Doorkeeper::ClientAuthentication::VerifiedCredentials.new("uid").freeze
        end
      end
      allow(Doorkeeper::Request).to receive(:client_authentication_method).and_return(strategy)
      server = described_class.new(double(:context, request: mock_request))

      expect { server.credentials }.not_to raise_error
      expect(server.credentials.authenticated_with).to eq("tls_client_auth")
      expect(server.credentials.uid).to eq("uid")
      expect(server.credentials).to be_pre_authenticated
    end

    # Freezing must not let a strategy keep a label of its own choosing: the
    # name a document client is held to is the server's record of which
    # strategy ran, never the strategy's word for itself.
    it "overwrites a name a frozen credential carried for itself" do
      strategy = Class.new do
        def self.matches_request?(_request) = true

        def self.auth_method_name = "tls_client_auth"

        def self.authenticate(_request)
          Doorkeeper::ClientAuthentication::VerifiedCredentials
            .new("uid", authenticated_with: "private_key_jwt").freeze
        end
      end
      allow(Doorkeeper::Request).to receive(:client_authentication_method).and_return(strategy)
      server = described_class.new(double(:context, request: mock_request))

      expect(server.credentials.authenticated_with).to eq("tls_client_auth")
    end

    it "returns nil when no method authenticates the request" do
      server = described_class.new(double(:context, request: mock_request))

      expect(server.credentials).to be_nil
    end
  end
end
