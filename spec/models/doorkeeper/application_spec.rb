require 'spec_helper_integration'

module Doorkeeper
  describe 'Application (aka Client)' do
    let(:new_application) { FactoryGirl.build(:application) }

    it 'expects database to throw an error when uids are the same' do
      app1 = FactoryGirl.create(:application)
      app2 = FactoryGirl.create(:application)
      app2.uid = app1.uid
      expect {
        app2.save!(:validate => false)
      }.to raise_error
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
        Doorkeeper.client.authorized_for(resource_owner).should be_empty
      end

      it "returns only application for a specific resource owner" do
        FactoryGirl.create(:access_token, :resource_owner_id => resource_owner.id + 1)
        token = FactoryGirl.create(:access_token, :resource_owner_id => resource_owner.id)
        Doorkeeper.client.authorized_for(resource_owner).should == [token.application]
      end

      it "excludes revoked tokens" do
        FactoryGirl.create(:access_token, :resource_owner_id => resource_owner.id, :revoked_at => 2.days.ago)
        Doorkeeper.client.authorized_for(resource_owner).should be_empty
      end

      it "returns all applications that have been authorized" do
        token1 = FactoryGirl.create(:access_token, :resource_owner_id => resource_owner.id)
        token2 = FactoryGirl.create(:access_token, :resource_owner_id => resource_owner.id)
        Doorkeeper.client.authorized_for(resource_owner).should == [token1.application, token2.application]
      end

      it "returns only one application even if it has been authorized twice" do
        application = FactoryGirl.create(:application)
        FactoryGirl.create(:access_token, :resource_owner_id => resource_owner.id, :application => application)
        FactoryGirl.create(:access_token, :resource_owner_id => resource_owner.id, :application => application)
        Doorkeeper.client.authorized_for(resource_owner).should == [application]
      end

      it "should fail to mass assign a new application" do
        mass_assign = { :name => 'Something',
                        :redirect_uri => 'http://somewhere.com/something',
                        :uid => 123,
                        :secret => 'something' }
        Doorkeeper.client.create(mass_assign).uid.should_not == 123
      end
    end
  end
end
