# frozen_string_literal: true

require "spec_helper"

module Doorkeeper::OAuth::Helpers
  describe URIChecker do
    describe ".valid?" do
      it "is valid for valid uris" do
        uri = "http://app.co"
        expect(described_class).to be_valid(uri)
      end

      it "is valid if include path param" do
        uri = "http://app.co/path"
        expect(described_class).to be_valid(uri)
      end

      it "is valid if include query param" do
        uri = "http://app.co/?query=1"
        expect(described_class).to be_valid(uri)
      end

      it "is invalid if uri includes fragment" do
        uri = "http://app.co/test#fragment"
        expect(described_class).not_to be_valid(uri)
      end

      it "is invalid if scheme is missing" do
        uri = "app.co"
        expect(described_class).not_to be_valid(uri)
      end

      it "is invalid if is a relative uri" do
        uri = "/abc/123"
        expect(described_class).not_to be_valid(uri)
      end

      it "is invalid if is not a url" do
        uri = "http://"
        expect(described_class).not_to be_valid(uri)
      end

      it "is invalid if localhost is resolved as as scheme (no scheme specified)" do
        uri = "localhost:8080"
        expect(described_class).not_to be_valid(uri)
      end

      it "is invalid if scheme is missing #2" do
        uri = "app.co:80"
        expect(described_class).not_to be_valid(uri)
      end

      it "is invalid if is not an uri" do
        uri = "   "
        expect(described_class).not_to be_valid(uri)
      end

      it "is valid for custom schemes" do
        uri = "com.example.app:/test"
        expect(described_class).to be_valid(uri)
      end

      it "is valid for custom schemes with authority marker (common misconfiguration)" do
        uri = "com.example.app://test"
        expect(described_class).to be_valid(uri)
      end
    end

    describe ".matches?" do
      it "is true if both url matches" do
        uri = client_uri = "http://app.co/aaa"
        expect(described_class).to be_matches(uri, client_uri)
      end

      it "doesn't allow additional query parameters" do
        uri = "http://app.co/?query=hello"
        client_uri = "http://app.co"
        expect(described_class).not_to be_matches(uri, client_uri)
      end

      it "doesn't allow non-matching domains through" do
        uri = "http://app.abc/?query=hello"
        client_uri = "http://app.co"
        expect(described_class).not_to be_matches(uri, client_uri)
      end

      it "doesn't allow non-matching domains that don't start at the beginning" do
        uri = "http://app.co/?query=hello"
        client_uri = "http://example.com?app.co=test"
        expect(described_class).not_to be_matches(uri, client_uri)
      end

      context "when loopback IP redirect URIs" do
        it "ignores port for same URIs" do
          uri = "http://127.0.0.1:5555/auth/callback"
          client_uri = "http://127.0.0.1:48599/auth/callback"
          expect(described_class).to be_matches(uri, client_uri)

          uri = "http://[::1]:5555/auth/callback"
          client_uri = "http://[::1]:5555/auth/callback"
          expect(described_class).to be_matches(uri, client_uri)
        end

        it "doesn't ignore port for URIs with different queries" do
          uri = "http://127.0.0.1:5555/auth/callback"
          client_uri = "http://127.0.0.1:48599/auth/callback2"
          expect(described_class).not_to be_matches(uri, client_uri)
        end
      end

      context "when client registered query params" do
        it "doesn't allow query being absent" do
          uri = "http://app.co"
          client_uri = "http://app.co/?vendorId=AJ4L7XXW9"
          expect(described_class).not_to be_matches(uri, client_uri)
        end

        it "is false if query values differ but key same" do
          uri = "http://app.co/?vendorId=pancakes"
          client_uri = "http://app.co/?vendorId=waffles"
          expect(described_class).not_to be_matches(uri, client_uri)
        end

        it "is false if query values same but key differs" do
          uri = "http://app.co/?foo=pancakes"
          client_uri = "http://app.co/?bar=pancakes"
          expect(described_class).not_to be_matches(uri, client_uri)
        end

        it "is false if query present and match, but unknown queries present" do
          uri = "http://app.co/?vendorId=pancakes&unknown=query"
          client_uri = "http://app.co/?vendorId=waffles"
          expect(described_class).not_to be_matches(uri, client_uri)
        end

        it "is true if queries are present and match" do
          uri = "http://app.co/?vendorId=AJ4L7XXW9&foo=bar"
          client_uri = "http://app.co/?vendorId=AJ4L7XXW9&foo=bar"
          expect(described_class).to be_matches(uri, client_uri)
        end

        it "is true if queries are present, match and in different order" do
          uri = "http://app.co/?bing=bang&foo=bar"
          client_uri = "http://app.co/?foo=bar&bing=bang"
          expect(described_class).to be_matches(uri, client_uri)
        end
      end
    end

    describe ".valid_for_authorization?" do
      it "is true if valid and matches" do
        uri = client_uri = "http://app.co/aaa"
        expect(described_class).to be_valid_for_authorization(uri, client_uri)

        uri = client_uri = "http://app.co/aaa?b=c"
        expect(described_class).to be_valid_for_authorization(uri, client_uri)
      end

      it "is true if uri includes blank query" do
        uri = client_uri = "http://app.co/aaa?"
        expect(described_class).to be_valid_for_authorization(uri, client_uri)

        uri = "http://app.co/aaa?"
        client_uri = "http://app.co/aaa"
        expect(described_class).to be_valid_for_authorization(uri, client_uri)

        uri = "http://app.co/aaa"
        client_uri = "http://app.co/aaa?"
        expect(described_class).to be_valid_for_authorization(uri, client_uri)
      end

      it "is false if valid and mismatches" do
        uri = "http://app.co/aaa"
        client_uri = "http://app.co/bbb"
        expect(described_class).not_to be_valid_for_authorization(uri, client_uri)
      end

      it "is true if valid and included in array" do
        uri = "http://app.co/aaa"
        client_uri = "http://example.com/bbb\nhttp://app.co/aaa"
        expect(described_class).to be_valid_for_authorization(uri, client_uri)
      end

      it "is false if valid and not included in array" do
        uri = "http://app.co/aaa"
        client_uri = "http://example.com/bbb\nhttp://app.co/cc"
        expect(described_class).not_to be_valid_for_authorization(uri, client_uri)
      end

      it "is false if queries does not match" do
        uri = "http://app.co/aaa?pankcakes=abc"
        client_uri = "http://app.co/aaa?waffles=abc"
        expect(described_class.valid_for_authorization?(uri, client_uri)).to be false
      end

      it "calls .matches?" do
        uri = "http://app.co/aaa?pankcakes=abc"
        client_uri = "http://app.co/aaa?waffles=abc"
        expect(described_class).to receive(:matches?).with(uri, client_uri).once
        described_class.valid_for_authorization?(uri, client_uri)
      end

      it "calls .valid?" do
        uri = "http://app.co/aaa?pankcakes=abc"
        client_uri = "http://app.co/aaa?waffles=abc"
        expect(described_class).to receive(:valid?).with(uri).once
        described_class.valid_for_authorization?(uri, client_uri)
      end
    end

    describe ".query_matches?" do
      it "is true if no queries" do
        expect(described_class).to be_query_matches("", "")
        expect(described_class).to be_query_matches(nil, nil)
      end

      it "is true if same query" do
        expect(described_class).to be_query_matches("foo", "foo")
      end

      it "is false if different query" do
        expect(described_class).not_to be_query_matches("foo", "bar")
      end

      it "is true if same queries" do
        expect(described_class).to be_query_matches("foo&bar", "foo&bar")
      end

      it "is true if same queries, different order" do
        expect(described_class).to be_query_matches("foo&bar", "bar&foo")
      end

      it "is false if one different query" do
        expect(described_class).not_to be_query_matches("foo&bang", "foo&bing")
      end

      it "is true if same query with same value" do
        expect(described_class).to be_query_matches("foo=bar", "foo=bar")
      end

      it "is true if same queries with same values" do
        expect(described_class).to be_query_matches("foo=bar&bing=bang", "foo=bar&bing=bang")
      end

      it "is true if same queries with same values, different order" do
        expect(described_class).to be_query_matches("foo=bar&bing=bang", "bing=bang&foo=bar")
      end

      it "is false if same query with different value" do
        expect(described_class).not_to be_query_matches("foo=bar", "foo=bang")
      end

      it "is false if some queries missing" do
        expect(described_class).not_to be_query_matches("foo=bar", "foo=bar&bing=bang")
      end

      it "is false if some queries different value" do
        expect(described_class).not_to be_query_matches("foo=bar&bing=bang", "foo=bar&bing=banana")
      end
    end
  end
end
