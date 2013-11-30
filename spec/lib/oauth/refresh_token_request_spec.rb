require 'spec_helper_integration'

module Doorkeeper::OAuth
  describe RefreshTokenRequest do
    let(:server)         { double :server, :access_token_expires_in => 2.minutes }
    let!(:refresh_token) { FactoryGirl.create(:access_token, :use_refresh_token => true) }
    let(:client)         { refresh_token.application }
    let(:credentials)    { Client::Credentials.new(client.uid, client.secret) }

    subject {
      RefreshTokenRequest.new server, refresh_token, credentials
    }

    it 'issues a new token for the client' do
      expect {
        subject.authorize
      }.to change { client.access_tokens.count }.by(1)
    end

    it 'revokes the previous token' do
      expect {
        subject.authorize
      }.to change { refresh_token.revoked? }.from(false).to(true)
    end

    it 'requires the refresh token' do
      subject.refresh_token = nil
      subject.validate
      subject.error.should == :invalid_request
    end

    it 'requires credentials to be valid if provided' do
      subject.client = nil
      subject.validate
      subject.error.should == :invalid_client
    end

    it "requires the token's client and current client to match" do
      subject.client = FactoryGirl.create(:application)
      subject.validate
      subject.error.should == :invalid_grant
    end

    it 'rejects revoked tokens' do
      refresh_token.revoke
      subject.validate
      subject.error.should == :invalid_request
    end

    it 'accepts expired tokens' do
      refresh_token.expires_in = -1
      refresh_token.save
      subject.validate
      subject.should be_valid
    end

    context 'clientless access tokens' do
      let!(:refresh_token) { FactoryGirl.create(:clientless_access_token, :use_refresh_token => true) }

      subject {
        RefreshTokenRequest.new server, refresh_token, nil
      }

      it 'issues a new token without a client' do
        expect {
          subject.authorize
        }.to change { Doorkeeper::AccessToken.count }.by(1)
      end
    end

  end
end
