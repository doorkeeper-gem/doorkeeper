require 'spec_helper_integration'

module Doorkeeper::OAuth
  describe AuthorizationCodeRequest do
    let(:server) { mock :server, :access_token_expires_in => 2.days, :refresh_token_enabled? => false }
    let(:grant)  { FactoryGirl.create :access_grant }
    let(:client) { grant.application }

    subject do
      AuthorizationCodeRequest.new server, grant, client, :redirect_uri => client.redirect_uri
    end

    it 'issues a new token for the client' do
      expect do
        subject.authorize
      end.to change { client.access_tokens.count }.by(1)
    end

    it "issues the token with same grant's scopes" do
      subject.authorize
      Doorkeeper::AccessToken.last.scopes.should == grant.scopes
    end

    it 'revokes the grant' do
      expect do
        subject.authorize
      end.to change { grant.reload.accessible? }
    end

    it 'requires the grant to be accessible' do
      grant.revoke
      subject.validate
      subject.error.should == :invalid_grant
    end

    it 'requires the grant' do
      subject.grant = nil
      subject.validate
      subject.error.should == :invalid_grant
    end

    it 'requires the client' do
      subject.client = nil
      subject.validate
      subject.error.should == :invalid_client
    end

    it 'requires the redirect_uri' do
      subject.redirect_uri = nil
      subject.validate
      subject.error.should == :invalid_request
    end

    it "matches the redirect_uri with grant's one" do
      subject.redirect_uri = 'http://other.com'
      subject.validate
      subject.error.should == :invalid_grant
    end

    it "matches the client with grant's one" do
      subject.client = FactoryGirl.create :application
      subject.validate
      subject.error.should == :invalid_grant
    end
  end
end
