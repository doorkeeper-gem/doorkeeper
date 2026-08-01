# frozen_string_literal: true

require "spec_helper"

RSpec.describe Doorkeeper::ClientIdMetadata do
  let(:url) { "https://client.example.com/oauth-client" }

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
end
