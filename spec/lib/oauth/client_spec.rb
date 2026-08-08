# frozen_string_literal: true

require "spec_helper"

RSpec.describe Doorkeeper::OAuth::Client do
  describe "::Credentials (deprecated alias)" do
    it "still resolves to Doorkeeper::ClientAuthentication::Credentials" do
      credentials = with_deprecation_warnings(enabled: false) do
        Doorkeeper::OAuth::Client::Credentials
      end

      expect(credentials).to be(Doorkeeper::ClientAuthentication::Credentials)
    end

    it "warns on access when deprecation warnings are enabled" do
      expect { with_deprecation_warnings { Doorkeeper::OAuth::Client::Credentials } }
        .to output(/Doorkeeper::OAuth::Client::Credentials is deprecated/).to_stderr
    end

    def with_deprecation_warnings(enabled: true)
      original = Warning[:deprecated]
      Warning[:deprecated] = enabled
      yield
    ensure
      Warning[:deprecated] = original
    end
  end

  describe ".find" do
    let(:method) { double }

    it "finds the client via uid" do
      client = double
      expect(method).to receive(:call).with("uid").and_return(client)
      expect(described_class.find("uid", method))
        .to be_a(described_class)
    end

    it "returns nil if client was not found" do
      expect(method).to receive(:call).with("uid").and_return(nil)
      expect(described_class.find("uid", method)).to be_nil
    end
  end

  describe ".authenticate" do
    it "returns the authenticated client via credentials" do
      credentials = Doorkeeper::ClientAuthentication::Credentials.new("some-uid", "some-secret")
      authenticator = double
      expect(authenticator).to receive(:call).with("some-uid", "some-secret").and_return(double)
      expect(described_class.authenticate(credentials, authenticator))
        .to be_a(described_class)
    end

    it "returns nil if client was not authenticated" do
      credentials = Doorkeeper::ClientAuthentication::Credentials.new("some-uid", "some-secret")
      authenticator = double
      expect(authenticator).to receive(:call).with("some-uid", "some-secret").and_return(nil)
      expect(described_class.authenticate(credentials, authenticator)).to be_nil
    end

    # A pre-authenticated credential skips the secret comparison, so for a
    # metadata document client the method that produced it must be the one the
    # document selected. Otherwise any strategy a host application registers
    # could stand in for the document's choice — including for a document that
    # selected "none", which authenticates nobody.
    context "with a pre-authenticated credential for a metadata document client" do
      let(:client_id) { "https://client.example.com/oauth-client" }

      def verified(method_name)
        Doorkeeper::ClientAuthentication::VerifiedCredentials.new(client_id, authenticated_with: method_name)
      end

      def stub_document(auth_method)
        document = Doorkeeper::ClientIdMetadata::Document.new(
          client_id,
          { "client_id" => client_id, "token_endpoint_auth_method" => auth_method },
        )
        allow(Doorkeeper::ClientIdMetadata).to receive(:document_for).with(client_id).and_return(document)
      end

      before do
        config_is_set(:client_id_metadata_documents, true)
        # Resolution always succeeds here, so the only thing that can refuse
        # these credentials is the method check under test.
        allow(Doorkeeper::ClientIdMetadata).to receive(:resolve).with(client_id).and_return(double)
      end

      it "resolves the client when the document selected that method" do
        stub_document("private_key_jwt")

        expect(described_class.authenticate(verified("private_key_jwt"))).to be_a(described_class)
      end

      it "refuses a method the document did not select" do
        stub_document("private_key_jwt")

        expect(described_class.authenticate(verified("custom_method"))).to be_nil
      end

      it "refuses any method when the document selected none" do
        stub_document("none")

        expect(described_class.authenticate(verified("custom_method"))).to be_nil
      end

      it "refuses a credential that does not say how it authenticated" do
        stub_document("private_key_jwt")

        expect(described_class.authenticate(
                 Doorkeeper::ClientAuthentication::VerifiedCredentials.new(client_id),
               )).to be_nil
      end
    end

    # The same rule holds for credentials carrying a secret, not only for
    # pre-authenticated ones: a document naming "none" would otherwise also be
    # satisfied by client_secret_basic with an empty password, which
    # by_uid_and_secret resolves as public-client authentication.
    context "with ordinary credentials for a metadata document client" do
      let(:client_id) { "https://client.example.com/oauth-client" }

      def credentials(method_name, secret = nil)
        Doorkeeper::ClientAuthentication::Credentials.new(client_id, secret).tap do |c|
          c.authenticated_with = method_name
        end
      end

      def stub_document(auth_method)
        document = Doorkeeper::ClientIdMetadata::Document.new(
          client_id,
          { "client_id" => client_id, "token_endpoint_auth_method" => auth_method },
        )
        allow(Doorkeeper::ClientIdMetadata).to receive(:document_for).with(client_id).and_return(document)
      end

      before do
        config_is_set(:client_id_metadata_documents, true)
        allow(Doorkeeper::ClientIdMetadata).to receive(:resolve).with(client_id).and_return(double)
      end

      it "resolves a public document client through the none method" do
        stub_document("none")
        authenticator = ->(*) { double }

        expect(described_class.authenticate(credentials("none"), authenticator)).to be_a(described_class)
      end

      it "refuses client_secret_basic with a blank secret when the document selected none" do
        stub_document("none")
        authenticator = ->(*) { double }

        expect(described_class.authenticate(credentials("client_secret_basic", ""), authenticator)).to be_nil
      end

      it "refuses the none method when the document selected private_key_jwt" do
        stub_document("private_key_jwt")
        authenticator = ->(*) { double }

        expect(described_class.authenticate(credentials("none"), authenticator)).to be_nil
      end

      it "refuses credentials that do not say how they authenticated" do
        stub_document("none")
        authenticator = ->(*) { double }

        expect(described_class.authenticate(
                 Doorkeeper::ClientAuthentication::Credentials.new(client_id), authenticator,
               )).to be_nil
      end
    end

    it "leaves opaque client_ids unaffected by the document check" do
      credentials = Doorkeeper::ClientAuthentication::VerifiedCredentials.new("some-uid")
      allow(Doorkeeper.config.application_model).to receive(:by_uid).with("some-uid").and_return(double)

      expect(described_class.authenticate(credentials)).to be_a(described_class)
    end
  end
end
