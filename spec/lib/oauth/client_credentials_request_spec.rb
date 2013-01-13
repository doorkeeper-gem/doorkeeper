require 'spec_helper_integration'

module Doorkeeper::OAuth
  describe ClientCredentialsRequest do
    let(:server) { mock :server, :default_scopes => Doorkeeper::OAuth::Scopes.new, :access_token_expires_in => 2.hours }
    let(:client) { FactoryGirl.create(:application) }

    subject { ClientCredentialsRequest.new(server, client) }

    it 'issues an access token for the current client' do
      expect do
        subject.authorize
      end.to change { Doorkeeper::AccessToken.where(:application_id => client.id).count }.by(1)
    end

    it 'requires the client' do
      subject.client = nil
      subject.validation.validate
      subject.error.should == :invalid_client
    end

    it 'has successful response when issue was created' do
      subject.authorize
      subject.response.should be_a(TokenResponse)
    end

    context 'with scopes' do
      subject do
        ClientCredentialsRequest.new(server, client, :scope => 'public')
      end

      it 'validates the current scope' do
        server.stub :scopes => Doorkeeper::OAuth::Scopes.from_string('another')
        subject.validation.validate
        subject.error.should == :invalid_scope
      end

      it 'creates the token with scopes' do
        server.stub :scopes => Doorkeeper::OAuth::Scopes.from_string("public")
        expect {
          subject.authorize
        }.to change { Doorkeeper::AccessToken.count }.by(1)
        Doorkeeper::AccessToken.last.scopes.should include(:public)
      end
    end
  end
end
