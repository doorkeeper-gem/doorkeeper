require 'spec_helper'
require 'uri'
require 'doorkeeper/oauth/helpers/uri_checker'

module Doorkeeper::OAuth::Helpers
  describe URIChecker do
    describe ".valid?" do
      it "is valid for valid uris" do
        uri = "http://app.co"
        expect(URIChecker.valid?(uri)).to be_true
      end

      it "is valid if include path param" do
        uri = "http://app.co/path"
        expect(URIChecker.valid?(uri)).to be_true
      end

      it "is valid if include query param" do
        uri = "http://app.co/?query=1"
        expect(URIChecker.valid?(uri)).to be_true
      end

      it "is invalid if uri includes fragment" do
        uri = "http://app.co/test#fragment"
        expect(URIChecker.valid?(uri)).to be_false
      end

      it "is invalid if scheme is missing" do
        uri = "app.co"
        expect(URIChecker.valid?(uri)).to be_false
      end

      it "is invalid if is a relative uri" do
        uri = "/abc/123"
        expect(URIChecker.valid?(uri)).to be_false
      end

      it "is invalid if is not a url" do
        uri = "http://"
        expect(URIChecker.valid?(uri)).to be_false
      end
    end

    describe ".matches?" do
      it "is true if both url matches" do
        uri = client_uri = 'http://app.co/aaa'
        expect(URIChecker.matches?(uri, client_uri)).to be_true
      end

      it "ignores query parameter on comparsion" do
        uri = 'http://app.co/?query=hello'
        client_uri = 'http://app.co'
        expect(URIChecker.matches?(uri, client_uri)).to be_true
      end
    end

    describe ".valid_for_authorization?" do
      it "is true if valid and matches" do
        uri = client_uri = 'http://app.co/aaa'
        expect(URIChecker.valid_for_authorization?(uri, client_uri)).to be_true
      end

      it "is false if valid and mismatches" do
        uri = 'http://app.co/aaa'
        client_uri = 'http://app.co/bbb'
        expect(URIChecker.valid_for_authorization?(uri, client_uri)).to be_false
      end

      it "is true if valid and included in array" do
        uri = 'http://app.co/aaa'
        client_uri = "http://example.com/bbb\nhttp://app.co/aaa"
        expect(URIChecker.valid_for_authorization?(uri, client_uri)).to be_true
      end

      it "is false if valid and not included in array" do
        uri = 'http://app.co/aaa'
        client_uri = "http://example.com/bbb\nhttp://app.co/cc"
        expect(URIChecker.valid_for_authorization?(uri, client_uri)).to be_false
      end
    end
  end
end
