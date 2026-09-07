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

  # A row materialized from a metadata document keeps its stamp after
  # use_client_id_metadata_documents is turned off, and nothing refreshes it
  # any more. It must not fall through to opaque resolution as an ordinary
  # application on stale metadata — a public "none" row would keep
  # authorizing and redeeming tokens although no one ever registered it.
  describe "materialized rows after the feature is disabled" do
    let(:application) do
      FactoryBot.create(:application, uid: "https://client.example.com/oauth-client")
    end

    it "does not find a stamped row" do
      application.update!(client_id_metadata_materialized_at: Time.now.utc)

      expect(described_class.find(application.uid)).to be_nil
    end

    it "does not authenticate a stamped row" do
      application.update!(client_id_metadata_materialized_at: Time.now.utc)
      credentials = Doorkeeper::ClientAuthentication::Credentials
        .new(application.uid, application.plaintext_secret)

      expect(described_class.authenticate(credentials)).to be_nil
    end

    # The stamp, not the uid's shape, is what marks a row as the feature's:
    # an application someone registered with a URL-shaped uid stays a
    # registered application.
    it "still finds a registered application whose uid merely looks like a URL" do
      expect(described_class.find(application.uid)).to be_a(described_class)
    end
  end

  # Draft Section 7.2 permits pre-registering Client Identifier URLs, and
  # Section 7.1 says the https:// prefix alone cannot tell one from a
  # document client — the stamp does. A registered (un-stamped) application
  # holding a URL uid therefore keeps resolving as itself once the feature is
  # on, its URL never fetched, while a stamped row or a URL no application
  # holds is resolved through the document.
  describe "URL client_ids while the feature is enabled" do
    let(:url) { "https://client.example.com/oauth-client" }
    let(:application) { FactoryBot.create(:application, uid: url) }

    before { config_is_set(:client_id_metadata_documents, true) }

    it "finds a registered application holding the URL without fetching it" do
      fetch = stub_request(:get, url)

      expect(described_class.find(application.uid).application).to eq(application)
      expect(fetch).not_to have_been_requested
    end

    it "authenticates a registered application holding the URL by its secret" do
      fetch = stub_request(:get, url)
      credentials = Doorkeeper::ClientAuthentication::Credentials
        .new(application.uid, application.plaintext_secret)

      expect(described_class.authenticate(credentials).application).to eq(application)
      expect(fetch).not_to have_been_requested
    end

    # What resolve hands back is a distinct object, so that a client built
    # from it can only have come through the document path.
    it "resolves a URL no application holds through its metadata document" do
      resolved = FactoryBot.build(:application, uid: url)
      allow(Doorkeeper::ClientIdMetadata).to receive(:resolve).with(url).and_return(resolved)

      expect(described_class.find(url).application).to be(resolved)
    end

    it "resolves a stamped row through its metadata document" do
      application.update!(client_id_metadata_materialized_at: Time.now.utc)
      resolved = FactoryBot.build(:application, uid: url)
      allow(Doorkeeper::ClientIdMetadata).to receive(:resolve).with(url).and_return(resolved)

      expect(described_class.find(url).application).to be(resolved)
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

      # Such a credential could never pass, so the document is not even
      # fetched for it — a fetch is an outbound request an unauthenticated
      # caller would otherwise be able to trigger at will.
      it "refuses a credential that does not say how it authenticated, without fetching the document" do
        expect(Doorkeeper::ClientIdMetadata).not_to receive(:document_for)

        expect(described_class.authenticate(
                 Doorkeeper::ClientAuthentication::VerifiedCredentials.new(client_id),
               )).to be_nil
      end
    end

    # The method that verified the assertion decided which keys to verify it
    # against, and this lookup resolves the same uid a second time. Between the
    # two an application row can be registered, removed, or have its
    # materialized stamp cleared — and the gap holds an outbound document fetch
    # whose duration whoever serves the document decides. A provenance that no
    # longer agrees is refused rather than resolved the other way round.
    context "with a pre-authenticated credential stating which keys verified it" do
      let(:url) { "https://client.example.com/oauth-client" }

      def verified(from_metadata_document)
        Doorkeeper::ClientAuthentication::VerifiedCredentials.new(
          url,
          authenticated_with: "private_key_jwt",
          from_metadata_document: from_metadata_document,
        )
      end

      before do
        config_is_set(:client_id_metadata_documents, true)
        document = Doorkeeper::ClientIdMetadata::Document.new(
          url,
          { "client_id" => url, "token_endpoint_auth_method" => "private_key_jwt" },
        )
        allow(Doorkeeper::ClientIdMetadata).to receive(:document_for).with(url).and_return(document)
        # Stamped, as every row the factory materializes is: what a resolution
        # hands back is what the provenance recheck below reads.
        allow(Doorkeeper::ClientIdMetadata).to receive(:resolve).with(url).and_return(
          FactoryBot.build(:application, uid: url, client_id_metadata_materialized_at: Time.now.utc),
        )
      end

      it "resolves the client while the provenance still agrees" do
        expect(described_class.authenticate(verified(true))).to be_a(described_class)
      end

      # The assertion was verified against whatever the URL serves, and the URL
      # is now a registered application whose keys the signer never had.
      it "refuses a document-verified credential once an application holds the URL" do
        FactoryBot.create(:application, uid: url)

        expect(described_class.authenticate(verified(true))).to be_nil
      end

      # The other way round: verified against a registered application's keys,
      # resolving now would materialize a row from a document instead.
      it "refuses a registration-verified credential once the URL resolves through a document" do
        expect(described_class.authenticate(verified(false))).to be_nil
      end

      # The disagreement is decided from the row alone, so it costs no fetch —
      # an unauthenticated caller must not be able to trigger one at will.
      it "refuses without fetching the document" do
        expect(Doorkeeper::ClientIdMetadata).not_to receive(:document_for)

        expect(described_class.authenticate(verified(false))).to be_nil
      end

      # The provenance check above is made against a lookup of its own, and
      # find makes another one: a row holding the URL can be registered, or
      # removed, in between those two queries. What find resolved is therefore
      # held to the same answer, read off the row it handed back.
      it "refuses when an application comes to hold the URL between the two lookups" do
        FactoryBot.create(:application, uid: url)
        allow(Doorkeeper::ClientIdMetadata).to receive(:resolves_through_document?).and_return(true, false)

        expect(described_class.authenticate(verified(true))).to be_nil
      end

      it "refuses when the URL starts resolving through a document between the two lookups" do
        allow(Doorkeeper::ClientIdMetadata).to receive(:resolves_through_document?).and_return(false, true)

        expect(described_class.authenticate(verified(false))).to be_nil
      end

      # Every other method leaves this unanswered, and the resolution is the
      # one it always was.
      it "resolves a credential that states no provenance" do
        credentials = Doorkeeper::ClientAuthentication::VerifiedCredentials.new(
          url,
          authenticated_with: "private_key_jwt",
        )

        expect(described_class.authenticate(credentials)).to be_a(described_class)
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

      # Credentials carrying a secret are refused before the document is
      # looked at: no document could make them acceptable, and looking is a
      # fetch.
      it "refuses a presented secret without fetching the document" do
        expect(Doorkeeper::ClientIdMetadata).not_to receive(:document_for)
        authenticator = ->(*) { double }

        expect(described_class.authenticate(credentials("client_secret_post", "guess"), authenticator)).to be_nil
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
