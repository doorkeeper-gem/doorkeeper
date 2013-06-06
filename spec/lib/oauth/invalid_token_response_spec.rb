require 'spec_helper'
require 'active_model'
require 'doorkeeper'
require 'doorkeeper/oauth/invalid_token_response'

module Doorkeeper::OAuth
  describe InvalidTokenResponse do
    its(:name)  { should == :invalid_token }
    its(:status) { should == :unauthorized }

    describe :from_access_token do
      it 'revoked' do
        response = InvalidTokenResponse.from_access_token stub(:revoked? => true, :expired? => true)
        expect(response.description).to match /revoked/
      end

      it 'expired' do
        response = InvalidTokenResponse.from_access_token stub(:revoked? => false, :expired? => true)
        expect(response.description).to match /expired/
      end
    end

    describe '.authenticate_info' do
      subject { InvalidTokenResponse.from_access_token stub(:revoked? => true) }
      its(:authenticate_info) { should == 'Bearer error="invalid_token", error_description="The access_token is revoked"' }
    end
    describe '.headers' do
      subject { InvalidTokenResponse.from_access_token stub(:revoked? => true) }
      its(:headers) { should have_key 'WWW-Authenticate' }
    end
  end
end
