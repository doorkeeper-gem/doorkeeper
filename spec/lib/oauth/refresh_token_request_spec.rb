require 'spec_helper_integration'

module Doorkeeper::OAuth
  describe RefreshTokenRequest, "refresh token" do
    let(:client) { FactoryGirl.create(:application) }
    let(:access) { FactoryGirl.create(:access_token, :application => client, :use_refresh_token => true) }
    let(:params) {
      {
        :refresh_token => access.refresh_token,
        :grant_type    => "refresh_token",
      }
    }

    before do
      Doorkeeper.configure {
        orm DOORKEEPER_ORM
        use_refresh_token
      }
    end

    describe "with a valid authorization code and client" do
      subject { RefreshTokenRequest.new(client, params) }

      before do
        subject.authorize
      end

      it { should be_valid }
      its(:token_type)    { should == "bearer" }
      its(:error)         { should be_nil }
      its(:refresh_token) { should_not be_nil }

      it "has an access token" do
        subject.access_token.token.should =~ /\w+/
      end
    end

    describe "with errors" do
      def token(params)
        RefreshTokenRequest.new(client, params)
      end

      it "includes the error in the response" do
        access_token = token(params.except(:grant_type))
        access_token.error_response.name.should == :invalid_request
      end

      [:grant_type, :refresh_token].each do |param|
        describe "when :#{param} is missing" do
          subject     { token(params.except(param)) }
          its(:error) { should == :invalid_request }
        end
      end

      describe "when client is not present" do
        subject     { RefreshTokenRequest.new(nil, params) }
        its(:error) { should == :invalid_client }
      end

      describe "when :refresh_token does not exist" do
        subject     { token(params.merge(:refresh_token => "inexistent")) }
        its(:error) { should == :invalid_grant }
      end

      describe "when :grant_type is not 'refresh_token'" do
        subject     { token(params.merge(:grant_type => "invalid")) }
        its(:error) { should == :invalid_request }
      end

      describe "when granted application does not match" do
        subject { token(params) }

        before do
          access.application = FactoryGirl.create(:application)
          access.save!
        end

        its(:error) { should == :invalid_grant }
      end

      describe "when :refresh_token is revoked" do
        it "error is :invalid_grant" do
          access.revoke # create grant instance
          revoked = token(params)
          revoked.error.should == :invalid_grant
        end
      end
    end
  end
end
