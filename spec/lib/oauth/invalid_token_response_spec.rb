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
        response.description.should include("revoked")
      end

      it 'expired' do
        response = InvalidTokenResponse.from_access_token stub(:revoked? => false, :expired? => true)
        response.description.should include("expired")
      end
    end
  end
end
