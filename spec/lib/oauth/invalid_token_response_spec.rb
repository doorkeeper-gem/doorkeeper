require 'spec_helper'
require 'active_model'
require 'doorkeeper'
require 'doorkeeper/oauth/invalid_token_response'

module Doorkeeper::OAuth
  describe InvalidTokenResponse do
    describe '#name' do
      it  { expect(subject.name).to eq(:invalid_token) }
    end

    describe '#status' do
      it { expect(subject.status).to eq(:unauthorized) }
    end

    describe :from_access_token do
      it 'revoked' do
        response = InvalidTokenResponse.from_access_token double(revoked?: true, expired?: true)
        expect(response.description).to include('revoked')
      end

      it 'expired' do
        response = InvalidTokenResponse.from_access_token double(revoked?: false, expired?: true)
        expect(response.description).to include('expired')
      end
    end
  end
end
