require 'spec_helper_integration'

class Doorkeeper::OAuth::ClientCredentialsRequest
  describe Creator do
    let(:client) { FactoryGirl.create :application }
    let(:scopes) { Doorkeeper::OAuth::Scopes.from_string('public') }

    it 'creates a new token' do
      expect do
        subject.call(client, scopes)
      end.to change { Doorkeeper::AccessToken.count }.by(1)
    end

    it 'returns false if creation fails' do
      Doorkeeper::AccessToken.should_receive(:create).and_return(false)
      created = subject.call(client, scopes)
      created.should be_false
    end

    it 'does not create a new token if there is an accessible one' do
      subject.call(client, scopes, :expires_in => 10.years)
      expect do
        subject.call(client, scopes)
      end.to_not change { Doorkeeper::AccessToken.count }
    end

    it 'returns the existing token if there is an accessible one' do
      existing = subject.call(client, scopes, :expires_in => 10.years)
      created  = subject.call(client, scopes)
      created.should == existing
    end

    it 'revokes old token if is not accessible' do
      existing = subject.call(client, scopes, :expires_in => -1000)
      subject.call(client, scopes)
      existing.reload.should be_revoked
    end

    it 'returns a new token when the old one is not accessible' do
      existing = subject.call(client, scopes, :expires_in => -1000)

      expect do
        subject.call(client, scopes)
      end.to change { Doorkeeper::AccessToken.count }.by(1)
    end
  end
end
