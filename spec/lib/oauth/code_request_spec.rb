require 'spec_helper_integration'

module Doorkeeper::OAuth
  describe CodeRequest do
    let(:pre_auth) do
      mock(:pre_auth, {
        :client => mock(:application, :id => 9990),
        :redirect_uri => 'http://tst.com/cb',
        :scopes => nil,
        :state => nil,
        :error => nil,
        :authorizable? => true
      })
    end

    let(:owner) { mock :owner, :id => 8900 }

    subject do
      CodeRequest.new(pre_auth, owner)
    end

    it 'creates an access grant' do
      expect do
        subject.authorize
      end.to change { Doorkeeper::AccessGrant.count }.by(1)
    end

    it 'returns a code response' do
      subject.authorize.should be_a(CodeResponse)
    end

    it 'does not create grant when not authorizable' do
      pre_auth.stub :authorizable? => false
      expect do
        subject.authorize
      end.to_not change { Doorkeeper::AccessGrant.count }
    end

    it 'returns a error response' do
      pre_auth.stub :authorizable? => false
      subject.authorize.should be_a(ErrorResponse)
    end
  end
end
