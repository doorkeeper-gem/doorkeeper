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
  end
end
