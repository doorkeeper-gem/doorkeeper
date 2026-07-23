# frozen_string_literal: true

require "spec_helper"

describe Doorkeeper::OAuth::Helpers::URIChecker do
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

    it "doesn't allow a trailing slash difference" do
      uri = "http://app.co/aaa/"
      client_uri = "http://app.co/aaa"
      expect(described_class).not_to be_matches(uri, client_uri)
    end

    it "doesn't allow a path case difference" do
      uri = "http://app.co/AAA"
      client_uri = "http://app.co/aaa"
      expect(described_class).not_to be_matches(uri, client_uri)
    end

    it "doesn't allow a host case difference" do
      uri = "http://APP.CO/aaa"
      client_uri = "http://app.co/aaa"
      expect(described_class).not_to be_matches(uri, client_uri)
    end

    it "doesn't allow a blank query difference" do
      uri = "http://app.co/aaa?"
      client_uri = "http://app.co/aaa"
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

    it "is false if one of the uris is not a valid URI" do
      uri = "http://app.co/aaa"
      client_uri = "http://app.co/ /aaa"
      expect(described_class).not_to be_matches(uri, client_uri)
    end

    it "is false if only one of the uris is a loopback URI" do
      uri = "http://127.0.0.1:5555/auth/callback"
      client_uri = "http://app.co/auth/callback"
      expect(described_class).not_to be_matches(uri, client_uri)
    end

    it "is true for identical custom-scheme URIs" do
      uri = client_uri = "com.example.app:/oauth/callback"
      expect(described_class).to be_matches(uri, client_uri)
    end

    it "is false for non-matching custom-scheme URIs" do
      uri = "com.example.app:/oauth/callback"
      client_uri = "com.example.app:/oauth/other"
      expect(described_class).not_to be_matches(uri, client_uri)

      uri = "com.example.app:/oauth/callback"
      client_uri = "com.example.other:/oauth/callback"
      expect(described_class).not_to be_matches(uri, client_uri)
    end

    context "when loopback IP redirect URIs" do
      it "ignores port for same URIs" do
        uri = "http://127.0.0.1:5555/auth/callback"
        client_uri = "http://127.0.0.1:48599/auth/callback"
        expect(described_class).to be_matches(uri, client_uri)

        uri = "http://[::1]:5555/auth/callback"
        client_uri = "http://[::1]:48599/auth/callback"
        expect(described_class).to be_matches(uri, client_uri)
      end

      it "ignores port when only the request URI specifies one" do
        uri = "http://127.0.0.1:5555/auth/callback"
        client_uri = "http://127.0.0.1/auth/callback"
        expect(described_class).to be_matches(uri, client_uri)

        uri = "http://[::1]:5555/auth/callback"
        client_uri = "http://[::1]/auth/callback"
        expect(described_class).to be_matches(uri, client_uri)
      end

      it "ignores port when only the client URI specifies one" do
        uri = "http://127.0.0.1/auth/callback"
        client_uri = "http://127.0.0.1:48599/auth/callback"
        expect(described_class).to be_matches(uri, client_uri)

        uri = "http://[::1]/auth/callback"
        client_uri = "http://[::1]:48599/auth/callback"
        expect(described_class).to be_matches(uri, client_uri)
      end

      it "doesn't ignore port for URIs with different paths" do
        uri = "http://127.0.0.1:5555/auth/callback"
        client_uri = "http://127.0.0.1:48599/auth/callback2"
        expect(described_class).not_to be_matches(uri, client_uri)
      end

      it "doesn't ignore port for URIs with different queries" do
        uri = "http://127.0.0.1:5555/auth/callback?foo=bar"
        client_uri = "http://127.0.0.1:48599/auth/callback?foo=baz"
        expect(described_class).not_to be_matches(uri, client_uri)
      end

      it "doesn't ignore port for URIs with an empty path vs root path difference" do
        uri = "http://127.0.0.1:5555"
        client_uri = "http://127.0.0.1:48599/"
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

      it "is false if queries are present and match but in different order" do
        uri = "http://app.co/?bing=bang&foo=bar"
        client_uri = "http://app.co/?foo=bar&bing=bang"
        expect(described_class).not_to be_matches(uri, client_uri)
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

    it "is true if uri includes blank query and client uri is identical" do
      uri = client_uri = "http://app.co/aaa?"
      expect(described_class).to be_valid_for_authorization(uri, client_uri)
    end

    it "is false if only one of the uris includes a blank query" do
      uri = "http://app.co/aaa?"
      client_uri = "http://app.co/aaa"
      expect(described_class).not_to be_valid_for_authorization(uri, client_uri)

      uri = "http://app.co/aaa"
      client_uri = "http://app.co/aaa?"
      expect(described_class).not_to be_valid_for_authorization(uri, client_uri)
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

  describe ".loopback_uri?" do
    it "is true if loopback IP" do
      expect(described_class).to be_loopback_uri(URI.parse("http://127.0.0.1"))
    end

    it "is false if not loopback IP" do
      expect(described_class).not_to be_loopback_uri(URI.parse("http://example.com"))
    end

    it "is false for non URL" do
      expect(described_class).not_to be_loopback_uri(URI.parse("vscode://file/home/user/.vimrc"))
    end
  end
end
