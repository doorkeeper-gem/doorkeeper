require 'spec_helper'

describe Doorkeeper, "configuration" do
  subject { Doorkeeper.configuration }

  describe "resource_owner_authenticator" do
    it "sets the block that is accessible via authenticate_resource_owner" do
      block = proc do end
      Doorkeeper.configure do
        resource_owner_authenticator &block
      end
      subject.authenticate_resource_owner.should == block
    end
  end

  describe "admin_authenticator" do
    it "sets the block that is accessible via authenticate_admin" do
      block = proc do end
      Doorkeeper.configure do
        admin_authenticator &block
      end
      subject.authenticate_admin.should == block
    end
  end

  describe "access_token_expires_in" do
    it "has 2 hours by default" do
      subject.access_token_expires_in.should == 2.hours
    end

    it "can change the value" do
      Doorkeeper.configure do
        access_token_expires_in 4.hours
      end
      subject.access_token_expires_in.should == 4.hours
    end
  end

  describe "scopes" do
    it "can be set with authorization_scopes method in DSL" do
      Doorkeeper.configure do
        authorization_scopes do
          scope :public, :default => true, :description => "Public"
        end
      end

      subject.scopes[:public].should_not be_nil
      subject.scopes[:public].description.should == "Public"
      subject.scopes[:public].default.should == true
    end
  end
end
