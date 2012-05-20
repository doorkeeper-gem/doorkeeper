require 'spec_helper'
require 'active_support/core_ext/module/delegation'
require 'active_support/core_ext/string'
require 'doorkeeper/oauth/client'
require 'doorkeeper/oauth/client/methods'
require 'doorkeeper/oauth/client/credentials'

module Doorkeeper::OAuth
  class Doorkeeper::Application
  end

  describe Client do
    describe :find do
      let(:uid) { "some-uid" }

      it 'finds the client via uid' do
        client = stub
        Doorkeeper::Application.should_receive(:find_by_uid).with(uid).and_return(client)
        Client.find(uid).should be_a(Client)
      end

      it 'returns nil if client was not found' do
        Doorkeeper::Application.should_receive(:find_by_uid).with(uid).and_return(nil)
        Client.find(uid).should be_nil
      end
    end

    describe :authenticate do
      it 'returns the authenticated client via credentials' do
        credentials = Client::Credentials.new("some-uid", "some-secret")
        authenticator = mock
        authenticator.should_receive(:call).with("some-uid", "some-secret").and_return(stub)
        Client.authenticate(credentials, authenticator).should be_a(Client)
      end

      it 'retunrs nil if client was not authenticated' do
        credentials = Client::Credentials.new("some-uid", "some-secret")
        authenticator = mock
        authenticator.should_receive(:call).with("some-uid", "some-secret").and_return(nil)
        Client.authenticate(credentials, authenticator).should be_nil
      end
    end
  end
end
