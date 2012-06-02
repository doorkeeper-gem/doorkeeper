require 'spec_helper_integration'

module Doorkeeper::OAuth
  describe AccessTokenRequest do
    let(:client) { FactoryGirl.create(:application) }
    let(:grant)  { FactoryGirl.create(:access_grant, :application => client) }
    let(:params) {
      {
        :code          => grant.token,
        :grant_type    => "authorization_code",
        :redirect_uri  => client.redirect_uri
      }
    }

    describe "with a valid authorization code and client" do
      subject { AccessTokenRequest.new(client, params) }

      before { subject.authorize }

      it { should be_valid }
      its(:token_type)    { should == "bearer" }
      its(:error)         { should be_nil }
      its(:refresh_token) { should be_nil }

      it "has an access token" do
        subject.access_token.token.should =~ /\w+/
      end
    end

    describe "creating the access token" do
      subject { AccessTokenRequest.new(client, params) }

      it "creates with correct params" do
        Doorkeeper::AccessToken.should_receive(:create!).with({
          :application_id    => client.id,
          :resource_owner_id => grant.resource_owner_id,
          :expires_in        => 2.hours,
          :scopes            =>"public write",
          :use_refresh_token => false,
        })
        subject.authorize
      end
    end

    describe "with a valid authorization code, client and existing valid access token" do
      subject { AccessTokenRequest.new(client, params) }

      before { subject.authorize }
      it { should be_valid }
      its(:error)         { should be_nil }

      it "will not create a new token" do
        subject.should_not_receive(:create_access_token)
        subject.authorize
      end
    end

    describe "with a valid authorization code, client and existing expired access token" do
      before do
        AccessTokenRequest.new(client, params).authorize
        last_token = Doorkeeper::AccessToken.last
        # TODO: make this better, maybe with an expire! method?
        last_token.update_attribute :created_at, 10.days.ago
      end

      it "will create a new token" do
        grant = FactoryGirl.create(:access_grant, :application => client)
        authorization = AccessTokenRequest.new(client, params.merge(:code => grant.token))
        expect {
          authorization.authorize
        }.to change { Doorkeeper::AccessToken.count }.by(1)
      end
    end

    describe "finding the current access token" do
      subject { AccessTokenRequest.new(client, params) }
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
      subject { AccessTokenRequest.new(client, params) }
      it { should be_valid }
      its(:error)         { should be_nil }

      it "should create a new access token" do
        subject.should_receive(:create_access_token)
        subject.authorize
      end
    end

    describe "with errors" do
      def token(params)
        AccessTokenRequest.new(client, params)
      end

      it "includes the error in the response" do
        access_token = token(params.except(:grant_type))
        access_token.error_response.name.should == :invalid_request
      end

      [:grant_type, :code, :redirect_uri].each do |param|
        describe "when :#{param} is missing" do
          subject     { token(params.except(param)) }
          its(:error) { should == :invalid_request }
        end
      end

      describe "when client is not present" do
        subject     { AccessTokenRequest.new(nil, params) }
        its(:error) { should == :invalid_client }
      end

      describe "when :code does not exist" do
        subject     { token(params.merge(:code => "inexistent")) }
        its(:error) { should == :invalid_grant }
      end

      describe "when :redirect_uri does not match with grant's one" do
        subject     { token(params.merge(:redirect_uri => "another")) }
        its(:error) { should == :invalid_grant }
      end

      describe "when :grant_type is not 'authorization_code'" do
        subject     { token(params.merge(:grant_type => "invalid")) }
        its(:error) { should == :unsupported_grant_type }
      end

      describe "when granted application does not match" do
        subject { token(params) }

        before do
          grant.application = FactoryGirl.create(:application)
          grant.save!
        end

        its(:error) { should == :invalid_grant }
      end

      describe "when :code is expired" do
        it "error is :invalid_grant" do
          grant # create grant instance
          Timecop.freeze(Time.now + 700.seconds) do
            expired = token(params)
            expired.error.should == :invalid_grant
          end
        end
      end
    end
  end

  describe AccessTokenRequest, "refresh token" do
    let(:client) { FactoryGirl.create(:application) }
    let(:access) { FactoryGirl.create(:access_token, :application => client, :use_refresh_token => true) }
    let(:params) {
      {
        :refresh_token => access.refresh_token,
        :grant_type    => "refresh_token",
      }
    }

    before do
      Doorkeeper.configure { use_refresh_token }
    end

    describe "with a valid authorization code and client" do
      subject { AccessTokenRequest.new(client, params) }

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
        AccessTokenRequest.new(client, params)
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
        subject     { AccessTokenRequest.new(nil, params) }
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
