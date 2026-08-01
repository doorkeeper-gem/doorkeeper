# frozen_string_literal: true

require "spec_helper"

RSpec.describe Doorkeeper::ClientIdMetadata::UrlValidator do
  describe ".valid?" do
    it "accepts an https URL with a path" do
      expect(described_class.valid?("https://client.example.com/oauth-client")).to be true
    end

    it "accepts a URL with a port" do
      expect(described_class.valid?("https://client.example.com:8443/oauth-client")).to be true
    end

    it "accepts a URL with a query string (SHOULD NOT, but tolerated)" do
      expect(described_class.valid?("https://client.example.com/oauth-client?v=1")).to be true
    end

    # The scheme is compared case-insensitively when a client_id is recognized
    # as a URL, so a validator that disagreed would turn such a client_id into
    # a permanent invalid_client instead of resolving it.
    it "accepts an uppercase scheme" do
      expect(described_class.valid?("HTTPS://client.example.com/oauth-client")).to be true
    end

    # URI.parse accepts any integer as a port, but a value too large to be one
    # makes Net::HTTP raise TypeError while building the connection address —
    # not an error a fetch is prepared for.
    it "rejects a port outside the range a TCP port can occupy" do
      expect(described_class.valid?("https://client.example.com:99999999999999999999/app")).to be false
    end

    it "rejects a zero port" do
      expect(described_class.valid?("https://client.example.com:0/app")).to be false
    end

    it "rejects an http URL" do
      expect(described_class.valid?("http://client.example.com/oauth-client")).to be false
    end

    it "rejects other schemes" do
      expect(described_class.valid?("ftp://client.example.com/oauth-client")).to be false
    end

    # Draft Section 3 asks for a path component; "/" is one, and a client_id
    # ending there is a URL a client may well publish.
    it "accepts a URL whose path is only a slash" do
      expect(described_class.valid?("https://client.example.com/")).to be true
    end

    it "rejects a URL without a path component" do
      expect(described_class.valid?("https://client.example.com")).to be false
    end

    it "rejects a URL with a fragment" do
      expect(described_class.valid?("https://client.example.com/oauth-client#frag")).to be false
    end

    it "rejects a URL with a username" do
      expect(described_class.valid?("https://user@client.example.com/oauth-client")).to be false
    end

    it "rejects a URL with a username and password" do
      expect(described_class.valid?("https://user:pass@client.example.com/oauth-client")).to be false
    end

    # URI#userinfo answers nil for an empty one, but Section 3 forbids the
    # component and the delimiter is the component — otherwise this is a
    # second client_id for the same origin and path.
    it "rejects a URL with an empty userinfo" do
      expect(described_class.valid?("https://@client.example.com/oauth-client")).to be false
      expect(described_class.valid?("https://:@client.example.com/oauth-client")).to be false
    end

    it "rejects single-dot path segments" do
      expect(described_class.valid?("https://client.example.com/./oauth-client")).to be false
    end

    it "rejects double-dot path segments" do
      expect(described_class.valid?("https://client.example.com/../oauth-client")).to be false
    end

    it "rejects a trailing double-dot path segment" do
      expect(described_class.valid?("https://client.example.com/a/..")).to be false
    end

    it "rejects percent-encoded single-dot path segments" do
      expect(described_class.valid?("https://client.example.com/%2e/oauth-client")).to be false
    end

    it "rejects percent-encoded double-dot path segments" do
      expect(described_class.valid?("https://client.example.com/%2e%2e/oauth-client")).to be false
    end

    it "rejects mixed-case percent-encoded dot segments" do
      expect(described_class.valid?("https://client.example.com/%2E%2e/oauth-client")).to be false
    end

    it "rejects partially encoded double-dot path segments" do
      expect(described_class.valid?("https://client.example.com/.%2e/oauth-client")).to be false
    end

    it "accepts a percent-encoded segment that is not a dot segment" do
      expect(described_class.valid?("https://client.example.com/oauth%2Dclient")).to be true
    end

    it "accepts a URL right at the maximum length" do
      url = "https://client.example.com/#{"a" * (described_class::MAX_LENGTH - 27)}"

      expect(url.length).to eq(described_class::MAX_LENGTH)
      expect(described_class.valid?(url)).to be true
    end

    # The uid column the URL is stored in is a string, which MySQL sizes at
    # 255 characters; a longer client_id could never be materialized.
    it "rejects a URL longer than the uid column can hold" do
      url = "https://client.example.com/#{"a" * (described_class::MAX_LENGTH - 26)}"

      expect(url.length).to eq(described_class::MAX_LENGTH + 1)
      expect(described_class.valid?(url)).to be false
    end

    it "rejects unparseable URLs" do
      expect(described_class.valid?("https://client example com/oauth-client")).to be false
    end

    it "rejects blank values" do
      expect(described_class.valid?(nil)).to be false
      expect(described_class.valid?("")).to be false
    end
  end
end
