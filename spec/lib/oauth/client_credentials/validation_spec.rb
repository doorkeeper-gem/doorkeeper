require 'spec_helper'
require 'active_support/all'
require 'doorkeeper/oauth/client_credentials/validation'

class Doorkeeper::OAuth::ClientCredentialsRequest
  describe Validation do
    let(:server)  { mock :server, :scopes => nil }
    let(:request) { mock :request, :client => stub, :original_scopes => nil }

    subject { Validation.new(server, request) }

    it 'is valid with valid request' do
      subject.should be_valid
    end

    it 'is invalid when client is not present' do
      request.stub :client => nil
      subject.should_not be_valid
    end

    context 'with scopes' do
      it 'is invalid when scopes are not included in the server' do
        server.stub :scopes => Doorkeeper::OAuth::Scopes.from_string('email')
        request.stub :original_scopes => 'invalid'
        subject.should_not be_valid
      end
    end
  end
end
