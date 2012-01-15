require 'spec_helper'
require 'active_support/core_ext/string'
require 'uri'
require 'rack/utils'
require 'doorkeeper/oauth/authorization/uri_builder'

module Doorkeeper::OAuth::Authorization
  describe URIBuilder do

    subject { Object.new.class.send :include, URIBuilder }

    describe :uri_with_query do
      it 'returns the uri with query' do
        uri = subject.uri_with_query 'http://example.com/', :parameter => 'value'
        uri.should == 'http://example.com/?parameter=value'
      end

      it 'rejects nil values' do
        uri = subject.uri_with_query 'http://example.com/', :parameter => ""
        uri.should == 'http://example.com/?'
      end

      it 'preserves original query parameters' do
        uri = subject.uri_with_query 'http://example.com/?query1=value', :parameter => 'value'
        uri.should =~ /query1=value/
        uri.should =~ /parameter=value/
      end
    end

    describe :uri_with_fragment do
      it 'returns uri with parameters as fragments' do
        uri = subject.uri_with_fragment 'http://example.com/', :parameter => 'value'
        uri.should == 'http://example.com/#parameter=value'
      end
    end
  end
end
