require 'spec_helper'
require 'active_support/core_ext/string'
require 'doorkeeper/oauth/client'

class Doorkeeper::OAuth::Client
  describe Credentials do
    it 'is blank when any of the credentials is blank' do
      expect(Credentials.new(nil, 'something')).to be_blank
      expect(Credentials.new('something', nil)).to be_blank
    end

    describe :from_request do
      let(:request) { double.as_null_object }

      let(:method) do
        ->(_request) { return 'uid', 'secret' }
      end

      it 'accepts anything that responds to #call' do
        expect(method).to receive(:call).with(request)
        Credentials.from_request request, method
      end

      it 'delegates methods received as symbols to Credentials class' do
        expect(Credentials).to receive(:from_params).with(request)
        Credentials.from_request request, :from_params
      end

      it 'stops at the first credentials found' do
        not_called_method = double
        expect(not_called_method).not_to receive(:call)
        Credentials.from_request request, ->(_) {}, method, not_called_method
      end

      it 'returns new Credentials' do
        credentials = Credentials.from_request request, method
        expect(credentials).to be_a(Credentials)
      end

      it 'returns uid and secret from extractor method' do
        credentials = Credentials.from_request request, method
        expect(credentials.uid).to    eq('uid')
        expect(credentials.secret).to eq('secret')
      end
    end
  end
end
