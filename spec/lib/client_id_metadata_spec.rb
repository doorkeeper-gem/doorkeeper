# frozen_string_literal: true

require "spec_helper"

RSpec.describe Doorkeeper::ClientIdMetadata do
  let(:url) { "https://client.example.com/oauth-client" }
  let(:body) do
    {
      "client_id" => url,
      "client_name" => "Example App",
      "redirect_uris" => ["https://app.example.com/callback"],
      "token_endpoint_auth_method" => "none",
    }.to_json
  end

  before do
    described_class.document_cache.clear
    allow(Resolv).to receive(:getaddresses).and_return(["93.184.216.34"])
  end

  describe ".url_client_id?" do
    it "is false while the feature is disabled" do
      expect(described_class.url_client_id?(url)).to be false
    end

    context "when enabled" do
      before { config_is_set(:client_id_metadata_documents, true) }

      it "is true for https client_ids" do
        expect(described_class.url_client_id?(url)).to be true
      end

      it "matches the scheme case-insensitively (RFC 3986)" do
        expect(described_class.url_client_id?("HTTPS://client.example.com/oauth-client")).to be true
      end

      it "is false for opaque client_ids" do
        expect(described_class.url_client_id?("abc123")).to be false
      end
    end
  end

  # Draft Section 8.5 has the consent screen display the client_id host next to
  # whatever the document claimed about itself, since the host is the one part
  # of the identity the client demonstrably controls.
  describe ".display_host" do
    def materialized(uid)
      FactoryBot.build(:application, uid: uid, client_id_metadata_materialized_at: Time.now.utc)
    end

    # The row still appears on the authorized applications page after the
    # option is turned off, and its already-issued tokens are still live, so
    # the resource owner deciding what to revoke keeps the one part of the
    # identity the client demonstrably controls.
    it "keeps naming the host of a materialized row while the feature is disabled" do
      expect(described_class.display_host(materialized(url))).to eq("client.example.com")
    end

    it "is nil for a registered application, feature disabled or not" do
      registered = FactoryBot.build(:application, uid: url)

      expect(described_class.display_host(registered)).to be_nil

      config_is_set(:client_id_metadata_documents, true)
      expect(described_class.display_host(registered)).to be_nil
    end

    context "when enabled" do
      before { config_is_set(:client_id_metadata_documents, true) }

      it "returns the host of a document client's client_id URL" do
        expect(described_class.display_host(materialized(url))).to eq("client.example.com")
      end

      # Two client_ids differing only in the port are two clients (the draft
      # compares the URLs as strings), so the port has to be part of what
      # tells them apart on screen.
      it "keeps a non-default port" do
        expect(described_class.display_host(materialized("https://client.example.com:8443/oauth-client")))
          .to eq("client.example.com:8443")
      end

      it "leaves the default port out" do
        expect(described_class.display_host(materialized("https://client.example.com:443/oauth-client")))
          .to eq("client.example.com")
      end

      it "is nil for a registered application with an opaque uid" do
        expect(described_class.display_host(FactoryBot.build(:application, uid: "abc123"))).to be_nil
      end

      # Draft Section 7.2: a URL may be pre-registered. Nothing was fetched
      # from it, so its host vouches for nothing and must not be shown as
      # if it had been.
      it "is nil for a registered application whose uid merely looks like a URL" do
        expect(described_class.display_host(FactoryBot.build(:application, uid: url))).to be_nil
      end

      it "is nil when the client_id carries no host" do
        expect(described_class.display_host(materialized("https://"))).to be_nil
      end

      # .url_client_id? only matches the scheme prefix, so a client_id can
      # reach the parse below and still not be a URL at all.
      it "is nil when the client_id is not parseable as a URL" do
        expect(described_class.display_host(materialized("https://exa mple.com/oauth-client"))).to be_nil
      end
    end
  end

  describe ".resolve" do
    before { config_is_set(:client_id_metadata_documents, true) }

    it "fetches, validates and materializes the client" do
      stub_request(:get, url).to_return(status: 200, body: body)

      application = described_class.resolve(url)

      expect(application.uid).to eq(url)
      expect(application.name).to eq("Example App")
    end

    it "memoizes the document across resolutions" do
      request_stub = stub_request(:get, url).to_return(status: 200, body: body)

      2.times { described_class.resolve(url) }

      expect(request_stub).to have_been_requested.once
    end

    it "returns nil for an invalid client_id URL" do
      expect(described_class.resolve("https://client.example.com")).to be_nil
    end

    it "returns nil when the fetch fails" do
      stub_request(:get, url).to_return(status: 404)

      expect(described_class.resolve(url)).to be_nil
    end

    it "returns nil when the document is invalid" do
      stub_request(:get, url).to_return(status: 200, body: "{}")

      expect(described_class.resolve(url)).to be_nil
    end

    it "returns nil when the host answers with something that is not an HTTP response" do
      stub_request(:get, url).to_raise(Net::HTTPBadResponse.new("wrong status line"))

      expect(described_class.resolve(url)).to be_nil
    end

    it "returns nil when the document is not served as JSON" do
      stub_request(:get, url).to_return(status: 200, body: body, headers: { "Content-Type" => "text/html" })

      expect(described_class.resolve(url)).to be_nil
    end

    it "does not cache failed fetches" do
      stub_request(:get, url).to_return({ status: 404 }, { status: 200, body: body })

      expect(described_class.resolve(url)).to be_nil
      expect(described_class.resolve(url)).not_to be_nil
    end
  end
end
