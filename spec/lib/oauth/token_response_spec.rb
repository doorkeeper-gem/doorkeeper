require 'spec_helper'
require 'doorkeeper/oauth/token_response'

module Doorkeeper::OAuth
  describe TokenResponse do
    subject { TokenResponse.new(stub.as_null_object) }

    it 'includes access token response headers' do
      headers = subject.headers
      headers.fetch('Cache-Control').should == 'no-store'
      headers.fetch('Pragma').should == 'no-cache'
    end

    it 'status is success' do
      subject.status.should == :success
    end

    describe '.body' do
      let(:access_token) do
        mock :access_token, {
          :token => 'some-token',
          :expires_in => '3600',
          :scopes_string => 'two scopes',
          :refresh_token => 'some-refresh-token',
          :token_type => 'bearer'
        }
      end

      subject { TokenResponse.new(access_token).body }

      it 'includes :access_token' do
        subject['access_token'].should == 'some-token'
      end

      it 'includes :token_type' do
        subject['token_type'].should == 'bearer'
      end

      it 'includes :expires_in' do
        subject['expires_in'].should == '3600'
      end

      it 'includes :scope' do
        subject['scope'].should == 'two scopes'
      end

      it 'includes :refresh_token' do
        subject['refresh_token'].should == 'some-refresh-token'
      end
    end
  end
end
