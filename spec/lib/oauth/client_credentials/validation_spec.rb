require 'spec_helper'
require 'active_support/all'
require 'doorkeeper/oauth/client_credentials/validation'

class Doorkeeper::OAuth::ClientCredentialsRequest
  describe Validation do
    let(:server)  { double :server, scopes: nil }
    let(:request) { double :request, client: double, original_scopes: nil }

    subject { Validation.new(server, request) }

    it 'is valid with valid request' do
      expect(subject).to be_valid
    end

    it 'is invalid when client is not present' do
      allow(request).to receive(:client).and_return(nil)
      expect(subject).not_to be_valid
    end

    context 'with scopes' do
      it 'is invalid when scopes are not included in the server' do
        allow(server).to receive(:scopes).and_return(Doorkeeper::OAuth::Scopes.from_string('email'))
        allow(request).to receive(:original_scopes).and_return('invalid')
        expect(subject).not_to be_valid
      end
    end
  end
end
