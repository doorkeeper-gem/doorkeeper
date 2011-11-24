require "spec_helper"

module Doorkeeper::OAuth
  describe AccessTokenRequest do
    let(:client) { Factory(:application) }
    let(:grant)  { Factory(:access_grant, :application => client) }
    let(:params) {
      {
        :client_id     => client.uid,
        :client_secret => client.secret,
        :code          => grant.token,
        :grant_type    => "authorization_code",
        :redirect_uri  => client.redirect_uri
      }
    }

    describe "with a valid authorization code and client" do
      subject { AccessTokenRequest.new(grant.token, params) }

      before { subject.authorize }

      it { should be_valid }
      its(:access_token) { should =~ /\w+/ }
      its(:token_type)   { should == "bearer" }
      its(:error)        { should be_nil }
    end

    describe "with invalid parameters" do
      describe "retunrs :invalid_request" do
        [:grant_type, :code, :redirect_uri].each do |param|
          it "when :#{param} is missing" do
            token = AccessTokenRequest.new(grant.token, params.except(param))
            token.error_response['error'].should == "invalid_request"
          end
        end
      end

      describe "retunrs :invalid_client" do
        it "when :client_id does not match" do
          token = AccessTokenRequest.new(grant.token, params.merge(:client_id => "inexistent"))
          token.error_response['error'].should == "invalid_client"
        end

        it "when :client_secret does not match" do
          token = AccessTokenRequest.new(grant.token, params.merge(:client_secret => "inexistent"))
          token.error_response['error'].should == "invalid_client"
        end
      end

      describe "retunrs :invalid_grant" do
        it "when :code does not exist" do
          token = AccessTokenRequest.new(grant.token, params.merge(:code => "inexistent"))
          token.error_response['error'].should == "invalid_grant"
        end

        it "when :code is expired" do
          grant # create grant instance
          Timecop.freeze(Time.now + 700.seconds) do
            token = AccessTokenRequest.new(grant.token, params)
            token.error_response['error'].should == "invalid_grant"
          end
        end

        it "when granted application does not match" do
          grant.application = Factory(:application)
          grant.save!
          token = AccessTokenRequest.new(grant.token, params)
          token.error_response['error'].should == "invalid_grant"
        end

        it "when :redirect_uri does not match with grant's one" do
          token = AccessTokenRequest.new(grant.token, params.merge(:redirect_uri => "another"))
          token.error_response['error'].should == "invalid_grant"
        end
      end

      describe "retunrs :unsupported_grant_type" do
        it "when :grant_type is not 'authorization_code'" do
          token = AccessTokenRequest.new(grant.token, params.merge(:grant_type => "invalid"))
          token.error_response['error'].should == "unsupported_grant_type"
        end
      end
    end
  end
end
