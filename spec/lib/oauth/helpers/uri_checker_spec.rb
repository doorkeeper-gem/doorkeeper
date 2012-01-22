require 'spec_helper'
require 'uri'
require 'doorkeeper/oauth/helpers/uri_checker'

module Doorkeeper::OAuth::Helpers
  describe URIChecker do
    describe ".valid?" do
      it "is valid for valid uris" do
        uri = "http://app.co"
        URIChecker.valid?(uri).should be_true
      end

      it "is valid if include path param" do
        uri = "http://app.co/path"
        URIChecker.valid?(uri).should be_true
      end

      it "is valid if include query param" do
        uri = "http://app.co/?query=1"
        URIChecker.valid?(uri).should be_true
      end

      it "is invalid if uri includes fragment" do
        uri = "http://app.co/test#fragment"
        URIChecker.valid?(uri).should be_false
      end

      it "is invalid if scheme is missing" do
        uri = "app.co"
        URIChecker.valid?(uri).should be_false
      end

      it "is invalid if is a relative uri" do
        uri = "/abc/123"
        URIChecker.valid?(uri).should be_false
      end

      it "is invalid if is not a url" do
        uri = "http://"
        URIChecker.valid?(uri).should be_false
      end
    end

    describe ".matches?" do
      it "is true if both url matches" do
        uri = client_uri = 'http://app.co/aaa'
        URIChecker.matches?(uri, client_uri).should be_true
      end

      it "ignores query parameter on comparsion" do
        uri = 'http://app.co/?query=hello'
        client_uri = 'http://app.co'
        URIChecker.matches?(uri, client_uri).should be_true
      end
    end

    describe ".valid_for_authorization?" do
      it "is true if valid and matches" do
        uri = client_uri = 'http://app.co/aaa'
        URIChecker.valid_for_authorization?(uri, client_uri).should be_true
      end
    end
  end
end
