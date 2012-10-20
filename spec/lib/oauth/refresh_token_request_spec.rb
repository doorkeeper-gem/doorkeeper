require 'spec_helper_integration'

module Doorkeeper::OAuth
  describe RefreshTokenRequest do
    let(:server)        { mock :server, :access_token_expires_in => 2.minutes }
    let(:refresh_token) { FactoryGirl.create(:access_token, :use_refresh_token => true) }
    let(:client)        { refresh_token.application }

    it 'creates a new token' do
      request = RefreshTokenRequest.new(server, refresh_token, client)
      expect do
        request.authorize
      end.to change { Doorkeeper::AccessToken.count }.by(1)
    end

    describe "with a valid authorization code and client" do
      subject { RefreshTokenRequest.new(server, refresh_token, client) }

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
      describe "when :refresh_token is missing" do
        subject     { RefreshTokenRequest.new(server, nil, client) }
        its(:error) { should == :invalid_request }
      end

      describe "when client is not present" do
        subject     { RefreshTokenRequest.new(server, refresh_token, nil) }
        its(:error) { should == :invalid_client }
      end

      describe "when granted application does not match" do
        subject { RefreshTokenRequest.new(server, refresh_token, FactoryGirl.create(:application)) }

        its(:error) { should == :invalid_client }
      end

      describe "when :refresh_token is revoked" do
        it "error is :invalid_request" do
          refresh_token.revoke # create grant instance
          revoked = RefreshTokenRequest.new(server, refresh_token, client)
          revoked.error.should == :invalid_request
        end
      end
    end
  end
end
