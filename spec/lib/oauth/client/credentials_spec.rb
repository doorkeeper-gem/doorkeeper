require 'spec_helper'
require 'active_support/core_ext/string'
require 'doorkeeper/oauth/client/credentials'

class Doorkeeper::OAuth::Client
  describe Credentials do
    let(:client_id) { "some-uid" }
    let(:client_secret) { "some-secret" }

    it 'is blank when any of the credentials is blank' do
      Credentials.new(nil, "something").should be_blank
      Credentials.new("something", nil).should be_blank
    end

    describe :from_params do
      it 'returns credentials from parameters when Authorization header is not available' do
        request = stub :parameters => { :client_id => client_id, :client_secret => client_secret }
        credentials = Credentials.from_params(request)
        credentials.uid.should    == "some-uid"
        credentials.secret.should == "some-secret"
      end

      it 'is blank when there are no credentials' do
        request = stub :parameters => {}
        credentials = Credentials.from_params(request)
        credentials.should be_blank
      end
    end

    describe :from_basic do
      let(:credentials) { Base64.encode64("#{client_id}:#{client_secret}") }

      it 'decodes the credentials' do
        request = stub :env => { 'HTTP_AUTHORIZATION' => "Basic #{credentials}" }
        credentials = Credentials.from_basic(request)
        credentials.uid.should    == "some-uid"
        credentials.secret.should == "some-secret"
      end

      it 'is blank if Authorization is not Basic' do
        request = stub :env => { 'HTTP_AUTHORIZATION' => "#{credentials}" }
        credentials = Credentials.from_basic(request)
        credentials.should be_blank
      end
    end

    describe :from_request do
      let(:credentials) { Base64.encode64("id-from-header:secret-from-header") }

      let(:request) do
        stub :env => { 'HTTP_AUTHORIZATION' => "Basic #{credentials}" },
             :parameters => {
               :client_id => 'id-from-params',
               :client_secret => 'secret-from-params'
             }
      end

      it 'attempts to find credentials with methods order' do
        credentials = Credentials.from_request(request, :from_params, :from_basic)
        credentials.uid.should    == 'id-from-params'
        credentials.secret.should == 'secret-from-params'

        credentials = Credentials.from_request(request, :from_basic, :from_params)
        credentials.uid.should    == 'id-from-header'
        credentials.secret.should == 'secret-from-header'
      end
    end
  end
end
