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
