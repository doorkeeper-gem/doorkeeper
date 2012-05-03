require 'spec_helper'
require 'doorkeeper/oauth/client_credentials/response'

class Doorkeeper::OAuth::ClientCredentialsRequest
  describe Response do
    subject { Response.new(stub.as_null_object) }

    it 'includes access token response headers' do
      headers = subject.headers
      headers.fetch('Cache-Control').should == 'no-store'
      headers.fetch('Pragma').should == 'no-cache'
    end

    it 'status is success' do
      subject.status.should == :success
    end

    it 'token_type is bearer' do
      subject.token_type.should == 'bearer'
    end

    it 'can be serialized to JSON' do
      subject.should respond_to(:to_json)
    end

    context 'attributes' do
      let(:access_token) do
        mock :access_token, {
          :token => 'some-token',
          :expires_in => '3600',
          :scopes_string => 'two scopes'
        }
      end

      subject { Response.new(access_token).attributes }

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

      it 'does not include refresh_token (disabled in this flow)' do
        subject.should_not have_key('refresh_token')
      end
    end
  end
end
