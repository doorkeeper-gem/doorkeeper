require 'spec_helper_integration'

module Doorkeeper
  describe Application do
    let(:new_application) { Factory.build(:application) }

    it 'is valid given valid attributes' do
      new_application.should be_valid
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

    it 'is invalid without redirect_uri' do
      new_application.save
      new_application.redirect_uri = nil
      new_application.should_not be_valid
    end

    it 'is invalid with a redirect_uri that is relative' do
      new_application.save
      new_application.redirect_uri = "/abcd"
      new_application.should_not be_valid
    end

    it 'is invalid with a redirect_uri that has a fragment' do
      new_application.save
      new_application.redirect_uri = "http://example.com/abcd#xyz"
      new_application.should_not be_valid
    end

    it 'is invalid with a redirect_uri that has a query parameter' do
      new_application.save
      new_application.redirect_uri = "http://example.com/abcd?xyz=123"
      new_application.should_not be_valid
    end

    it 'checks uniqueness of uid' do
      app1 = Factory(:application)
      app2 = Factory(:application)
      app2.uid = app1.uid
      app2.should_not be_valid
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
    
    it 'should reduce application count on destroy' do
      new_application.save
      expect { new_application.destroy }.to change(Application, :count).by -1
    end
    
    it 'should destroy authorized_tokens and access_grants on delete' 

    describe :authorized_for do
      let(:resource_owner) { double(:resource_owner, :id => 10) }

      it "is empty if the application is not authorized for anyone" do
        Application.authorized_for(resource_owner).should be_empty
      end

      it "returns only application for a specific resource owner" do
        Factory(:access_token, :resource_owner_id => resource_owner.id + 1)
        token = Factory(:access_token, :resource_owner_id => resource_owner.id)
        Application.authorized_for(resource_owner).should == [token.application]
      end

      it "excludes revoked tokens" do
        Factory(:access_token, :resource_owner_id => resource_owner.id, :revoked_at => 2.days.ago)
        Application.authorized_for(resource_owner).should be_empty
      end

      it "returns all applications that have been authorized" do
        token1 = Factory(:access_token, :resource_owner_id => resource_owner.id)
        token2 = Factory(:access_token, :resource_owner_id => resource_owner.id)
        Application.authorized_for(resource_owner).should == [token1.application, token2.application]
      end

      it "returns only one application even if it has been authorized twice" do
        application = Factory(:application)
        Factory(:access_token, :resource_owner_id => resource_owner.id, :application => application)
        Factory(:access_token, :resource_owner_id => resource_owner.id, :application => application)
        Application.authorized_for(resource_owner).should == [application]
      end
    end
  end
end
