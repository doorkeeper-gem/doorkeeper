require 'spec_helper_integration'

module Doorkeeper::OAuth
  describe RefreshTokenRequest do
    let(:server)         { mock :server, :access_token_expires_in => 2.minutes }
    let!(:refresh_token) { FactoryGirl.create(:access_token, :use_refresh_token => true) }
    let(:client)         { refresh_token.application }

    subject do
      RefreshTokenRequest.new server, refresh_token, client
    end

    it 'issues a new token for the client' do
      expect do
        subject.authorize
      end.to change { client.access_tokens.count }.by(1)
    end

    it 'revokes the previous token' do
      expect do
        subject.authorize
      end.to change { refresh_token.revoked? }.from(false).to(true)
    end

    it 'requires the refresh token' do
      subject.refresh_token = nil
      subject.validate
      subject.error.should == :invalid_request
    end

    it 'requires client' do
      subject.client = nil
      subject.validate
      subject.error.should == :invalid_client
    end

    it "requires the token's client and current client to match" do
      subject.client = FactoryGirl.create(:application)
      subject.validate
      subject.error.should == :invalid_client
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
  end
end
