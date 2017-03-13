require 'spec_helper'
require 'uri'
require 'doorkeeper/oauth/helpers/uri_checker'

module Doorkeeper::OAuth::Helpers
  describe URIChecker do
    describe '.valid?' do
      it 'is valid for valid uris' do
        uri = 'http://app.co'
        expect(URIChecker.valid?(uri)).to be_truthy
      end

      it 'is valid if include path param' do
        uri = 'http://app.co/path'
        expect(URIChecker.valid?(uri)).to be_truthy
      end

      it 'is valid if include query param' do
        uri = 'http://app.co/?query=1'
        expect(URIChecker.valid?(uri)).to be_truthy
      end

      it 'is invalid if uri includes fragment' do
        uri = 'http://app.co/test#fragment'
        expect(URIChecker.valid?(uri)).to be_falsey
      end

      it 'is invalid if scheme is missing' do
        uri = 'app.co'
        expect(URIChecker.valid?(uri)).to be_falsey
      end

      it 'is invalid if is a relative uri' do
        uri = '/abc/123'
        expect(URIChecker.valid?(uri)).to be_falsey
      end

      it 'is invalid if is not a url' do
        uri = 'http://'
        expect(URIChecker.valid?(uri)).to be_falsey
      end
    end

    describe '.host_match?' do
      it 'is true for equal hosts' do
        uri = client_uri = 'http://app.co'
        expect(URIChecker.host_match?(uri, client_uri)).to be_truthy
      end

      it 'is true for subdomain hosts' do
        uri = 'http://whatever.app.co'
        client_uri = 'http://app.co'
        expect(URIChecker.host_match?(uri, client_uri)).to be_truthy

        uri = 'http://app.co'
        client_uri = 'http://whatever.app.co'
        expect(URIChecker.host_match?(uri, client_uri)).to be_truthy
      end

      it 'ignores path on comparsion' do
        uri = 'http://app.co/hello_world'
        client_uri = 'http://app.co'
        expect(URIChecker.host_match?(uri, client_uri)).to be_truthy
      end

      it 'ignores query parameter on comparsion' do
        uri = 'http://app.co/?query=testing'
        client_uri = 'http://app.co'
        expect(URIChecker.host_match?(uri, client_uri)).to be_truthy
      end

      it 'ignores path that look like domains on comparsion' do
        uri = 'http://app.com/app.co'
        client_uri = 'http://app.co'
        expect(URIChecker.host_match?(uri, client_uri)).to be_falsey
      end

      it 'fails for not matching domains' do
        uri = 'http://app.com/'
        client_uri = 'http://app.co'
        expect(URIChecker.host_match?(uri, client_uri)).to be_falsey
      end
    end

    describe '.matches_development_urls?' do
      it 'is true if url matches a client url' do
        Doorkeeper.configuration.instance_variable_set '@development_uris', 'http://example.co http://example.com'

        uri = 'http://example.com'
        expect(URIChecker.matches_development_urls?(uri)).to be_truthy
      end

      it 'is true even with subdomains' do
        Doorkeeper.configuration.instance_variable_set '@development_uris', 'http://example.co http://example.com'
        uri = 'http://subdomain.example.com'
        expect(URIChecker.matches_development_urls?(uri)).to be_true
      end

      it 'ignores query params' do
        Doorkeeper.configuration.instance_variable_set '@development_uris', 'http://example.co http://example.com'
        uri = 'http://example.com?foo=bar'
        expect(URIChecker.matches_development_urls?(uri)).to be_truthy
      end

      it 'fails if it does not match' do
        Doorkeeper.configuration.instance_variable_set '@development_uris', 'http://example.co http://example.com'
        uri = 'http://example.de'
        expect(URIChecker.matches_development_urls?(uri)).to be_falsey
      end

      it 'fails if config is disabled' do
        uri = 'http://example.de'
        expect(URIChecker.matches_development_urls?(uri)).to be_falsey
      end
    end

    describe '.matches?' do
      it 'is true if both url matches' do
        uri = client_uri = 'http://app.co/aaa'
        expect(URIChecker.matches?(uri, client_uri)).to be_truthy
      end

      it 'ignores query parameter on comparsion' do
        uri = 'http://app.co/?query=hello'
        client_uri = 'http://app.co'
        expect(URIChecker.matches?(uri, client_uri)).to be_truthy
      end

      it 'doesn\'t allow non-matching domains through' do
        uri = 'http://app.abc/?query=hello'
        client_uri = 'http://app.co'
        expect(URIChecker.matches?(uri, client_uri)).to be_falsey
      end

      it 'doesn\'t allow non-matching domains that don\'t start at the beginning' do
        uri = 'http://app.co/?query=hello'
        client_uri = 'http://example.com?app.co=test'
        expect(URIChecker.matches?(uri, client_uri)).to be_falsey
      end
    end

    describe '.valid_for_authorization?' do
      it 'is true if valid and matches' do
        uri = client_uri = 'http://app.co/aaa'
        expect(URIChecker.valid_for_authorization?(uri, client_uri)).to be_truthy
      end

      it 'is false if valid and mismatches' do
        uri = 'http://app.co/aaa'
        client_uri = 'http://app.co/bbb'
        expect(URIChecker.valid_for_authorization?(uri, client_uri)).to be_falsey
      end

      it 'is true if valid and included in array' do
        uri = 'http://app.co/aaa'
        client_uri = "http://example.com/bbb\nhttp://app.co/aaa"
        expect(URIChecker.valid_for_authorization?(uri, client_uri)).to be_truthy
      end

      it 'is false if valid and not included in array' do
        uri = 'http://app.co/aaa'
        client_uri = "http://example.com/bbb\nhttp://app.co/cc"
        expect(URIChecker.valid_for_authorization?(uri, client_uri)).to be_falsey
      end

      it 'is true if valid and matches' do
        uri = client_uri = 'http://app.co/aaa'
        expect(URIChecker.valid_for_authorization?(uri, client_uri)).to be true
      end

      it 'is false if invalid' do
        uri = client_uri = 'http://app.co/aaa?waffles=abc'
        expect(URIChecker.valid_for_authorization?(uri, client_uri)).to be false
      end
    end

    describe '.matches_development_urls?' do
      it 'is true for valid development uri' do
        Doorkeeper.configuration.instance_variable_set '@development_uris', 'http://localhost:3000 http://example.com'
        uri = 'http://localhost:3000'
        expect(URIChecker.matches_development_urls?(uri)).to be_truthy
      end

      it 'is true for valid development uri regardless of port' do
        Doorkeeper.configuration.instance_variable_set '@development_uris', 'http://localhost:3000 http://example.com'
        uri = 'http://localhost:1337'
        expect(URIChecker.matches_development_urls?(uri)).to be_truthy
      end

      it 'is false for default development_uris-setting' do
        uri = 'http://localhost:1337'
        expect(URIChecker.matches_development_urls?(uri)).to be_falsey
      end
    end
  end
end
