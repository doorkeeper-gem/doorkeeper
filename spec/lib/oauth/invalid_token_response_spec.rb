require 'spec_helper'
require 'active_model'
require 'doorkeeper'
require 'doorkeeper/oauth/invalid_token_response'

module Doorkeeper::OAuth
  describe InvalidTokenResponse do
    describe '#name' do
      subject { super().name }
      it  { should == :invalid_token }
    end

    describe '#status' do
      subject { super().status }
      it { should == :unauthorized }
    end

    describe :from_access_token do
      it 'revoked' do
        response = InvalidTokenResponse.from_access_token double(:revoked? => true, :expired? => true)
        expect(response.description).to include("revoked")
      end

      it 'expired' do
        response = InvalidTokenResponse.from_access_token double(:revoked? => false, :expired? => true)
        expect(response.description).to include("expired")
      end
    end
  end
end
