require 'spec_helper_integration'

module Doorkeeper::OAuth
  describe PasswordAccessTokenRequest do
    let(:client) { Factory(:application) }
    let(:owner)  { User.create!(:name => "Joe", :password => "sekret") }
    let(:params) {
      {
        :grant_type    => "password"
      }
    }

    describe "with a valid owner and client" do
      subject { PasswordAccessTokenRequest.new(client, owner, params) }

      before { subject.authorize }

      it { should be_valid }

      its(:token_type)    { should == "bearer" }
      its(:error)         { should be_nil }
      its(:refresh_token) { should be_nil }

      it "has an access token" do
        subject.access_token.token.should =~ /\w+/
      end
    end

    describe "with a valid client but an invalid owner" do
      subject { PasswordAccessTokenRequest.new(client, nil, params) }

      before { subject.authorize }

      it { should_not be_valid }
      its(:error)         { should == :invalid_resource_owner }
      its(:access_token)  { should be_nil }
      its(:refresh_token) { should be_nil }
    end

    describe "with a valid owner but an invalid client" do
      subject { PasswordAccessTokenRequest.new(nil, owner, params) }

      before { subject.authorize }

      it { should_not be_valid }
      its(:error)         { should == :invalid_client }
      its(:access_token)  { should be_nil }
      its(:refresh_token) { should be_nil }
    end

    describe "creating the access token" do
      subject { PasswordAccessTokenRequest.new(client, owner, params) }

      it "creates with correct params" do
        Doorkeeper::AccessToken.should_receive(:create!).with({
          :application_id    => client.id,
          :resource_owner_id => owner.id,
          :expires_in        => 2.hours,
          :scopes            =>"",
          :use_refresh_token => false,
        })
        subject.authorize
      end

      it "creates a refresh token if Doorkeeper is configured to do so" do
        Doorkeeper.configure { use_refresh_token }

        Doorkeeper::AccessToken.should_receive(:create!).with({
          :application_id    => client.id,
          :resource_owner_id => owner.id,
          :expires_in        => 2.hours,
          :scopes            =>"",
          :use_refresh_token => true,
        })
        subject.authorize
      end
    end

    describe "with an existing valid access token" do
      subject { PasswordAccessTokenRequest.new(client, owner, params) }

      before { subject.authorize }
      it { should be_valid }
      its(:error)         { should be_nil }

      it "will not create a new token" do
        subject.should_not_receive(:create_access_token)
        subject.authorize
      end
    end

    describe "with an existing expired access token" do
      subject { PasswordAccessTokenRequest.new(client, owner, params) }

      it "will create a new token" do
        subject.authorize
        expired_access_token = subject.access_token.dup
        subject.access_token.created_at = Time.now - subject.access_token.expires_in - 1.second
        subject.should_receive(:create_access_token)
        subject.access_token.should_receive(:revoke)
        subject.authorize
        subject.access_token.should_not eq(expired_access_token)
      end
    end

    describe "finding the current access token" do
      subject { PasswordAccessTokenRequest.new(client, owner, params) }
      it { should be_valid }
      its(:error)         { should be_nil }

      before { subject.authorize }

      it "should find the access token and not create a new one" do
        subject.should_not_receive(:create_access_token)
        access_token = subject.authorize
        subject.access_token.should eq(access_token)
      end
    end

    describe "creating the first access_token" do
      subject { PasswordAccessTokenRequest.new(client, owner, params) }
      it { should be_valid }
      its(:error)         { should be_nil }

      it "should create a new access token" do
        subject.should_receive(:create_access_token)
        subject.authorize
      end
    end

    describe "with errors" do
      def token(params)
        PasswordAccessTokenRequest.new(client, owner, params)
      end

      it "includes the error in the response" do
        access_token = token(params.except(:grant_type))
        access_token.error_response['error'].should == "invalid_request"
      end

      describe "when client is not present" do
        subject     { PasswordAccessTokenRequest.new(nil, owner, params) }
        its(:error) { should == :invalid_client }
      end

      describe "when :grant_type is not 'password'" do
        subject     { token(params.merge(:grant_type => "invalid")) }
        its(:error) { should == :unsupported_grant_type }
      end
    end
  end
end
