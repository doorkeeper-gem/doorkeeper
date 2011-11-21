require "spec_helper"

module Doorkeeper::OAuth
  describe AccessTokenRequest, "authorizing" do
    describe "an valid authorization code and client" do
      let(:grant)  { Factory(:access_grant) }
      let(:client) { Factory(:application) }
      let(:params) {
        { :client_id => client.uid,
          :client_secret => client.secret,
          :grant => grant.token
        }
      }

      subject { AccessTokenRequest.new(grant.token, params) }

      before do
        subject.authorize
      end

      its(:access_token) { should =~ /\w+/ }
      its(:token_type)   { "bearer" }
    end
  end
end
