require 'spec_helper'
require 'active_support/core_ext/string'
require 'doorkeeper/oauth/client/credentials'

class Doorkeeper::OAuth::Client
  describe Credentials do
    it 'is blank when any of the credentials is blank' do
      Credentials.new(nil, "something").should be_blank
      Credentials.new("something", nil).should be_blank
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
