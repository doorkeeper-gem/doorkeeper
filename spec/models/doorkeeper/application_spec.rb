require 'spec_helper_integration'

module Doorkeeper
  describe Application do
    include OrmHelper

    let(:require_owner) { Doorkeeper.configuration.instance_variable_set("@confirm_application_owner", true) }
    let(:unset_require_owner) { Doorkeeper.configuration.instance_variable_set("@confirm_application_owner", false) }
    let(:new_application) { FactoryGirl.build(:application) }

    context "application_owner is enabled" do
      before do
        Doorkeeper.configure do
          orm DOORKEEPER_ORM
          enable_application_owner
        end
      end

      context 'application owner is not required' do
        before(:each) do
          unset_require_owner
        end

        it 'is valid given valid attributes' do
          new_application.should be_valid
        end
      end

      context "application owner is required" do
        before(:each) do
          require_owner
          @owner = mock_application_owner
        end

        it 'is invalid without an owner' do
          new_application.should_not be_valid
        end

        it 'is valid with an owner' do
          new_application.owner = @owner
          new_application.should be_valid
        end
      end
    end

    it 'is invalid without a name' do
      new_application.name = nil
      new_application.should_not be_valid
    end

    it 'generates uid on create' do
      new_application.uid.should be_nil
      new_application.save
      new_application.uid.should_not be_nil
    end

    it 'is invalid without uid' do
      new_application.save
      new_application.uid = nil
      new_application.should_not be_valid
    end

    it 'is invalid with no redirect_uri when config forbids it' do
      Doorkeeper.configure do
          require_redirect_uri true
      end
      new_application.save
      new_application.redirect_uri = nil
      new_application.should_not be_valid
    end

    it 'is valid with no redirect_uri when config allows it' do
      Doorkeeper.configure do
          require_redirect_uri false
      end
      new_application.save
      new_application.redirect_uri = nil
      new_application.should be_valid
    end

    it 'is invalid with invalid redirect_uri' do
      new_application.save
      new_application.redirect_uri = "invalid_uri"
      new_application.should_not be_valid
    end

    it 'checks uniqueness of uid' do
      app1 = Factory(:application)
      app2 = Factory(:application)
      app2.uid = app1.uid
      app2.should_not be_valid
    end

    it 'expects database to throw an error when uids are the same' do
      app1 = FactoryGirl.create(:application)
      app2 = FactoryGirl.create(:application)
      app2.uid = app1.uid
      expect {
        app2.save!(:validate => false)
      }.to raise_error
    end

    it 'generate secret on create' do
      new_application.secret.should be_nil
      new_application.save
      new_application.secret.should_not be_nil
    end

    it 'is invalid without secret' do
      new_application.save
      new_application.secret = nil
      new_application.should_not be_valid
    end

    describe 'destroy related models on cascade' do
      before(:each) do
        new_application.save
      end

      it 'should destroy its access grants' do
        FactoryGirl.create(:access_grant, :application => new_application)
        expect { new_application.destroy }.to change { Doorkeeper::AccessGrant.count }.by(-1)
      end

      it 'should destroy its access tokens' do
        FactoryGirl.create(:access_token, :application => new_application)
        FactoryGirl.create(:access_token, :application => new_application, :revoked_at => Time.now)
        expect { new_application.destroy }.to change { Doorkeeper::AccessToken.count }.by(-2)
      end
    end

    describe :authorized_for do
      let(:resource_owner) { double(:resource_owner, :id => 10) }

      it "is empty if the application is not authorized for anyone" do
        Application.authorized_for(resource_owner).should be_empty
      end

      it "returns only application for a specific resource owner" do
        FactoryGirl.create(:access_token, :resource_owner_id => resource_owner.id + 1)
        token = FactoryGirl.create(:access_token, :resource_owner_id => resource_owner.id)
        Application.authorized_for(resource_owner).should == [token.application]
      end

      it "excludes revoked tokens" do
        FactoryGirl.create(:access_token, :resource_owner_id => resource_owner.id, :revoked_at => 2.days.ago)
        Application.authorized_for(resource_owner).should be_empty
      end

      it "returns all applications that have been authorized" do
        token1 = FactoryGirl.create(:access_token, :resource_owner_id => resource_owner.id)
        token2 = FactoryGirl.create(:access_token, :resource_owner_id => resource_owner.id)
        Application.authorized_for(resource_owner).should == [token1.application, token2.application]
      end

      it "returns only one application even if it has been authorized twice" do
        application = FactoryGirl.create(:application)
        FactoryGirl.create(:access_token, :resource_owner_id => resource_owner.id, :application => application)
        FactoryGirl.create(:access_token, :resource_owner_id => resource_owner.id, :application => application)
        Application.authorized_for(resource_owner).should == [application]
      end

      it "should fail to mass assign a new application" do
        mass_assign = { :name => 'Something',
                        :redirect_uri => 'http://somewhere.com/something',
                        :uid => 123,
                        :secret => 'something' }
        Application.create(mass_assign).uid.should_not == 123
      end
    end

    describe :authenticate do
      it 'finds the application via uid/secret' do
        app = FactoryGirl.create :application
        authenticated = Application.authenticate(app.uid, app.secret)
        authenticated.should == app
      end
    end
  end
end
