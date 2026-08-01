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
  end
end
