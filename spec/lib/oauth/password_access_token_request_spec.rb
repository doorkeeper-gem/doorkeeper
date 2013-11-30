require 'spec_helper_integration'

module Doorkeeper::OAuth
  describe PasswordAccessTokenRequest do
    let(:server) { mock :server, :default_scopes => Doorkeeper::OAuth::Scopes.new, :access_token_expires_in => 2.hours, :refresh_token_enabled? => false }
    let(:client) { FactoryGirl.create(:application) }
    let(:owner)  { mock :owner, :id => 99 }

    subject do
      PasswordAccessTokenRequest.new(server, client, owner)
    end

    it 'issues a new token for the client' do
      expect do
        subject.authorize
      end.to change { client.access_tokens.count }.by(1)
    end

    it "requires the owner" do
      subject.resource_owner = nil
      subject.validate
      subject.error.should == :invalid_resource_owner
    end

    it 'requires the client' do
      subject.client = nil
      subject.validate
      subject.error.should == :invalid_client
    end

    describe "with scopes" do
      subject do
        PasswordAccessTokenRequest.new(server, client, owner, :scope => 'public')
      end

      it 'validates the current scope' do
        server.stub :scopes => Doorkeeper::OAuth::Scopes.from_string('another')
        subject.validate
        subject.error.should == :invalid_scope
      end

      it 'creates the token with scopes' do
        server.stub :scopes => Doorkeeper::OAuth::Scopes.from_string("public")
        expect {
          subject.authorize
        }.to change { Doorkeeper::AccessToken.count }.by(1)
        Doorkeeper::AccessToken.last.scopes.should include('public')
      end
    end
  end
end
