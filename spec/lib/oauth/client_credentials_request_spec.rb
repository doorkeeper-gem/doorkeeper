require 'spec_helper'
require 'active_support/all'
require 'active_model'
require 'doorkeeper/oauth/client_credentials_request'

module Doorkeeper::OAuth
  describe ClientCredentialsRequest do
    let(:server) { stub :default_scopes => nil }
    let(:client) { stub }
    let(:token_creator) { mock :issuer, :create => true, :token => stub }

    subject { ClientCredentialsRequest.new(server, client) }

    before do
      subject.issuer = token_creator
    end

    it 'issues an access token for the current client' do
      token_creator.should_receive(:create).with(client, nil)
      subject.authorize
    end

    it 'has successful response when issue was created' do
      subject.authorize
      subject.response.should be_a(TokenResponse)
    end

    context 'if issue was not created' do
      before do
        subject.issuer = stub :create => false, :error => :invalid
      end

      it 'has an error response' do
        subject.authorize
        subject.response.should be_a(Doorkeeper::OAuth::ErrorResponse)
      end

      it 'delegates the error to issuer' do
        subject.authorize
        subject.error.should == :invalid
      end
    end

    context 'with scopes' do
      let(:default_scopes) { Doorkeeper::OAuth::Scopes.from_string("public email") }

      before do
        server.stub(:default_scopes).and_return(default_scopes)
      end

      it 'issues an access token with default scopes if none was requested' do
        token_creator.should_receive(:create).with(client, default_scopes)
        subject.authorize
      end

      it 'issues an access token with requested scopes' do
        subject = ClientCredentialsRequest.new(server, client, :scope => "email")
        subject.issuer = token_creator
        token_creator.should_receive(:create).with(client, Doorkeeper::OAuth::Scopes.from_string("email"))
        subject.authorize
      end
    end
  end
end
