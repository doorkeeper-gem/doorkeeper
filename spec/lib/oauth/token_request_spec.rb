require 'spec_helper_integration'

module Doorkeeper::OAuth
  describe TokenRequest do
    let :pre_auth do
      double(
        :pre_auth,
        client: double(:application, id: 9990),
        redirect_uri: 'http://tst.com/cb',
        state: nil,
        scopes: Scopes.from_string('public'),
        error: nil,
        authorizable?: true
      )
    end

    let :owner do
      double :owner, id: 7866
    end

    subject do
      TokenRequest.new(pre_auth, owner)
    end

    it 'creates an access token' do
      expect do
        subject.authorize
      end.to change { Doorkeeper::AccessToken.count }.by(1)
    end

    it 'returns a code response' do
      expect(subject.authorize).to be_a(CodeResponse)
    end

    it 'does not create token when not authorizable' do
      allow(pre_auth).to receive(:authorizable?).and_return(false)
      expect do
        subject.authorize
      end.to_not change { Doorkeeper::AccessToken.count }
    end

    it 'returns a error response' do
      allow(pre_auth).to receive(:authorizable?).and_return(false)
      expect(subject.authorize).to be_a(ErrorResponse)
    end

    context 'token reuse' do
      it 'creates a new token if there are no matching tokens' do
        Doorkeeper.configuration.stub(:reuse_access_token).and_return(true)
        expect do
          subject.authorize
        end.to change { Doorkeeper::AccessToken.count }.by(1)
      end

      it 'creates a new token if scopes do not match' do
        Doorkeeper.configuration.stub(:reuse_access_token).and_return(true)
        FactoryGirl.create(:access_token, application_id: pre_auth.client.id,
                           resource_owner_id: owner.id, scopes: '')
        expect do
          subject.authorize
        end.to change { Doorkeeper::AccessToken.count }.by(1)
      end

      it 'skips token creation if there is a matching one' do
        Doorkeeper.configuration.stub(:reuse_access_token).and_return(true)
        FactoryGirl.create(:access_token, application_id: pre_auth.client.id,
                           resource_owner_id: owner.id, scopes: 'public')
        expect do
          subject.authorize
        end.to_not change { Doorkeeper::AccessToken.count }
      end
    end
  end
end
