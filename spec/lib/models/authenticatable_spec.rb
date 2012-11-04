require 'spec_helper_integration'

describe Doorkeeper::Models::Authenticatable do
  subject do
    FactoryGirl.create :application
  end

  describe '.find_for_oauth_authentication' do
    it 'returns the client via uid' do
      client = Doorkeeper.client.find_for_oauth_authentication(subject.uid)
      client.should eq client
    end
  end

  describe '.oauth_authenticate' do
    it 'returns the application if uid/secret match' do
      client = perform_auth subject.uid, subject.secret
      client.should == subject
    end

    it 'returns nil if uid/secret doesn\'t match' do
      client = perform_auth 'invalid', subject.secret
      client.should be_nil

      client = perform_auth subject.uid, 'invalid'
      client.should be_nil
    end

    it 'ignores nil credentials' do
      subject.reset_credentials!

      client = perform_auth nil, nil
      client.should be_nil
    end

    def perform_auth(uid, secret)
      Doorkeeper.client.oauth_authenticate uid, secret
    end
  end
end
