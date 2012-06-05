require 'spec_helper'
require 'active_support/core_ext/string'
require 'doorkeeper/oauth/client'

class Doorkeeper::OAuth::Client
  describe Credentials do
    it 'is blank when any of the credentials is blank' do
      Credentials.new(nil, "something").should be_blank
      Credentials.new("something", nil).should be_blank
    end

    describe :from_request do
      let(:request) { stub.as_null_object }

      let(:method) do
        lambda { |request| return 'uid', 'secret' }
      end

      it 'accepts anything that responds to #call' do
        method.should_receive(:call).with(request)
        Credentials.from_request request, method
      end

      it 'delegates methods received as symbols to Credentials class' do
        Credentials.should_receive(:from_params).with(request)
        Credentials.from_request request, :from_params
      end

      it 'stops at the first credentials found' do
        not_called_method = mock
        not_called_method.should_not_receive(:call)
        credentials = Credentials.from_request request, lambda { |r| }, method, not_called_method
      end

      it 'returns new Credentials' do
        credentials = Credentials.from_request request, method
        credentials.should be_a(Credentials)
      end

      it 'returns uid and secret from extractor method' do
        credentials = Credentials.from_request request, method
        credentials.uid.should    == 'uid'
        credentials.secret.should == 'secret'
      end
    end
  end
end
