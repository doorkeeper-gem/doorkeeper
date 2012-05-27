require 'spec_helper'
require 'active_support/core_ext/string'
require 'doorkeeper/oauth/token'

module Doorkeeper
  unless defined?(AccessToken)
    class AccessToken
    end
  end

  module OAuth
    describe Token do
      describe :from_request do
        let(:request) { stub.as_null_object }

        let(:method) do
          lambda { |request| return 'token-value' }
        end

        it 'accepts anything that responds to #call' do
          method.should_receive(:call).with(request)
          Token.from_request request, method
        end

        it 'delegates methods received as symbols to Token class' do
          Token.should_receive(:from_params).with(request)
          Token.from_request request, :from_params
        end

        it 'stops at the first credentials found' do
          not_called_method = mock
          not_called_method.should_not_receive(:call)
          credentials = Token.from_request request, lambda { |r| }, method, not_called_method
        end

        it 'returns the credential from extractor method' do
          credentials = Token.from_request request, method
          credentials.should == 'token-value'
        end
      end

      describe :from_access_token_param do
        it 'returns token from access_token parameter' do
          request = stub :parameters => { :access_token => 'some-token' }
          token   = Token.from_access_token_param(request)
          token.should == "some-token"
        end
      end

      describe :from_bearer_param do
        it 'returns token from bearer_token parameter' do
          request = stub :parameters => { :bearer_token => 'some-token' }
          token   = Token.from_bearer_param(request)
          token.should == "some-token"
        end
      end

      describe :from_bearer_authorization do
        it 'returns token from authorization bearer' do
          request = stub :authorization => "Bearer SomeToken"
          token   = Token.from_bearer_authorization(request)
          token.should == "SomeToken"
        end

        it 'does not return token if authorization is not bearer' do
          request = stub :authorization => "MAC SomeToken"
          token   = Token.from_bearer_authorization(request)
          token.should be_blank
        end
      end

      describe :authenticate do
        let(:finder) { mock :finder }

        it 'calls the finder if token was found' do
          token = lambda { |r| 'token' }
          AccessToken.should_receive(:authenticate).with('token')
          Token.authenticate stub, token
        end
      end
    end
  end
end
