require 'spec_helper'
require 'doorkeeper/oauth/token_response'

module Doorkeeper::OAuth
  describe TokenResponse do
    subject { TokenResponse.new(double.as_null_object) }

    it 'includes access token response headers' do
      headers = subject.headers
      headers.fetch('Cache-Control').should == 'no-store'
      headers.fetch('Pragma').should == 'no-cache'
    end

    it 'status is ok' do
      subject.status.should == :ok
    end

    describe '.body' do
      let(:access_token) do
        double :access_token, {
          :token => 'some-token',
          :expires_in => '3600',
          :expires_in_seconds => '300',
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

      # expires_in_seconds is returned as `expires_in` in order to match
      # the OAuth spec (section 4.2.2)
      it 'includes :expires_in' do
        subject['expires_in'].should == '300'
      end

      it 'includes :scope' do
        subject['scope'].should == 'two scopes'
      end

      it 'includes :refresh_token' do
        subject['refresh_token'].should == 'some-refresh-token'
      end
    end

    describe '.body filters out empty values' do
      let(:access_token) do
        double :access_token, {
          :token => 'some-token',
          :expires_in_seconds => '',
          :scopes_string => '',
          :refresh_token => '',
          :token_type => 'bearer'
        }
      end

      subject { TokenResponse.new(access_token).body }

      it 'includes :expires_in' do
        subject['expires_in'].should be_nil
      end

      it 'includes :scope' do
        subject['scope'].should be_nil
      end

      it 'includes :refresh_token' do
        subject['refresh_token'].should be_nil
      end
    end
  end
end
