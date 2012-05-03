require 'spec_helper'
require 'active_support/core_ext/string'
require 'doorkeeper/oauth/client'

class Doorkeeper::OAuth::Client
  describe Credentials do
    let(:client_id) { "some-uid" }
    let(:client_secret) { "some-secret" }

    it 'is blank when any of the credentials is blank' do
      Credentials.new(nil, "something").should be_blank
      Credentials.new("something", nil).should be_blank
    end

    describe :from_request do
      context 'from params' do
        it 'returns credentials from parameters when Authorization header is not available' do
          request = stub :env => {}, :parameters => { :client_id => client_id, :client_secret => client_secret }
          credentials = Credentials.from_request(request)
          credentials.uid.should    == "some-uid"
          credentials.secret.should == "some-secret"
        end

        it 'is blank when there are no credentials' do
          request = stub :env => {}, :parameters => {}
          credentials = Credentials.from_request(request)
          credentials.should be_blank
        end
      end

      context 'from Authorization header' do
        let(:credentials) { Base64.encode64("#{client_id}:#{client_secret}") }

        it 'decodes the credentials' do
          request = stub :env => { 'HTTP_AUTHORIZATION' => "Basic #{credentials}" }, :parameters => {}
          credentials = Credentials.from_request(request)
          credentials.uid.should    == "some-uid"
          credentials.secret.should == "some-secret"
        end

        it 'is blank if Authorization is not Basic' do
          request = stub :env => { 'HTTP_AUTHORIZATION' => "#{credentials}" }, :parameters => {}
          credentials = Credentials.from_request(request)
          credentials.should be_blank
        end
      end
    end
  end
end
