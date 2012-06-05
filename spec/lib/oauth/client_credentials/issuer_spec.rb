require 'spec_helper'
require 'active_support/all'
require 'doorkeeper/oauth/client_credentials/issuer'

class Doorkeeper::OAuth::ClientCredentialsRequest
  describe Issuer do
    let(:creator) { mock :acces_token_creator }
    let(:server)  { mock :server, :access_token_expires_in => 100 }
    let(:validation) { mock :validation, :valid? => true }

    subject { Issuer.new(server, validation) }

    describe :create do
      let(:client) { mock :client, :id => 'some-id' }
      let(:scopes) { 'some scope' }

      it 'creates and sets the token' do
        creator.should_receive(:call).and_return('token')
        subject.create client, scopes, creator

        subject.token.should == 'token'
      end

      it 'creates with correct token parameters' do
        creator.should_receive(:call).with(client, scopes, {
          :expires_in        => 100,
          :use_refresh_token => false
        })

        subject.create client, scopes, creator
      end

      it 'has error set to :server_error if creator fails' do
        creator.should_receive(:call).and_return(false)
        subject.create client, scopes, creator

        subject.error.should == :server_error
      end

      context 'when validation fails' do
        before do
          validation.stub :valid? => false, :error => :validation_error
          creator.should_not_receive(:create)
        end

        it 'has error set from validation' do
          subject.create client, scopes, creator
          subject.error.should == :validation_error
        end

        it 'returns false' do
          subject.create(client, scopes, creator).should be_false
        end
      end
    end
  end
end
