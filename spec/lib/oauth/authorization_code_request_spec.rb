require 'spec_helper_integration'

module Doorkeeper::OAuth
  describe AuthorizationCodeRequest do
    let(:client) { FactoryGirl.create(:application) }
    let(:grant)  { FactoryGirl.create(:access_grant, :application => client) }
    let(:params) {
      {
        :code          => grant.token,
        :redirect_uri  => client.redirect_uri
      }
    }

    describe "with a valid authorization code and client" do
      subject { AuthorizationCodeRequest.new(client, params) }

      before { subject.authorize }

      it { should be_valid }
      its(:token_type)    { should == "bearer" }
      its(:error)         { should be_nil }

      it "has an access token" do
        subject.access_token.token.should =~ /\w+/
      end
    end

    describe "creating the access token" do
      subject { AuthorizationCodeRequest.new(client, params) }

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
      subject { AuthorizationCodeRequest.new(client, params) }

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
        AuthorizationCodeRequest.new(client, params).authorize
        last_token = Doorkeeper::AccessToken.last
        # TODO: make this better, maybe with an expire! method?
        last_token.update_column :created_at, 10.days.ago
      end

      it "will create a new token" do
        grant = FactoryGirl.create(:access_grant, :application => client)
        authorization = AuthorizationCodeRequest.new(client, params.merge(:code => grant.token))
        expect {
          authorization.authorize
        }.to change { Doorkeeper::AccessToken.count }.by(1)
      end
    end

    describe "finding the current access token" do
      subject { AuthorizationCodeRequest.new(client, params) }
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
      subject { AuthorizationCodeRequest.new(client, params) }
      it { should be_valid }
      its(:error)         { should be_nil }

      it "should create a new access token" do
        subject.should_receive(:create_access_token)
        subject.authorize
      end
    end

    describe "with errors" do
      def token(params)
        AuthorizationCodeRequest.new(client, params)
      end

      [:code, :redirect_uri].each do |param|
        describe "when :#{param} is missing" do
          subject     { token(params.except(param)) }
          its(:error) { should == :invalid_request }
        end
      end

      describe "when client is not present" do
        subject     { AuthorizationCodeRequest.new(nil, params) }
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
end
