# frozen_string_literal: true

require "spec_helper"

RSpec.describe Doorkeeper::OAuth::Authorization::URIBuilder do
  describe ".uri_with_query" do
    it "returns the uri with query" do
      uri = described_class.uri_with_query "http://example.com/", parameter: "value"
      expect(uri).to eq("http://example.com/?parameter=value")
    end

    it "rejects nil values" do
      uri = described_class.uri_with_query "http://example.com/", parameter: ""
      expect(uri).to eq("http://example.com/?")
    end

    it "preserves original query parameters" do
      uri = described_class.uri_with_query "http://example.com/?query1=value", parameter: "value"
      expect(uri).to match(/query1=value/)
      expect(uri).to match(/parameter=value/)
    end

    it "does not duplicate a parameter already present in the original query" do
      uri = described_class.uri_with_query "http://example.com/?state=fixed", code: "abc", state: "user-state"
      raw_query = URI.parse(uri).query
      query = Rack::Utils.parse_query(raw_query)
      param_names = raw_query.split("&").map { |pair| pair.split("=", 2).first }

      # The response parameter must override the one baked into the redirect_uri,
      # and it must appear exactly once (no `state=fixed&...&state=user-state`).
      expect(param_names.count("state")).to eq(1)
      expect(query["state"]).to eq("user-state")
      expect(query["code"]).to eq("abc")
    end

    it "retains an original query parameter when the same-named response parameter is blank" do
      # RFC 6749 §3.1.2: the registered query component must be retained when
      # adding additional query parameters. A blank response parameter (e.g. no
      # state was sent with the request) must not clobber it.
      uri = described_class.uri_with_query "http://example.com/?state=fixed", code: "abc", state: nil
      query = Rack::Utils.parse_query(URI.parse(uri).query)

      expect(query["state"]).to eq("fixed")
      expect(query["code"]).to eq("abc")
    end
  end

  describe ".uri_with_fragment" do
    it "returns uri with parameters as fragments" do
      uri = described_class.uri_with_fragment "http://example.com/", parameter: "value"
      expect(uri).to eq("http://example.com/#parameter=value")
    end

    it "preserves original query parameters" do
      uri = described_class.uri_with_fragment "http://example.com/?query1=value1", parameter: "value"
      expect(uri).to eq("http://example.com/?query1=value1#parameter=value")
    end
  end
end
