require 'spec_helper_integration'

module Doorkeeper::OAuth
  describe TokenRequest do
    let :pre_auth do
      double(
        :pre_auth,
        client: double(:application, id: 9990),
        redirect_uri: 'http://tst.com/cb',
        state: nil,
        scopes: nil,
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
  end
end
