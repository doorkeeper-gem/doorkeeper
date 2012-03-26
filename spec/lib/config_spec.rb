require 'spec_helper_integration'

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

    it "can be set to nil" do
      Doorkeeper.configure do
        access_token_expires_in nil
      end
      subject.access_token_expires_in.should be_nil
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

    it "returns empty Scopes collection if no scopes were defined" do
      Doorkeeper.configure do
      end

      subject.scopes.should be_a(Doorkeeper::Scopes)
      subject.scopes.all.should == []
    end
  end

  describe "use_refresh_token" do
    it "is false by default" do
      subject.refresh_token_enabled?.should be_false
    end

    it "can change the value" do
      Doorkeeper.configure { use_refresh_token }
      subject.refresh_token_enabled?.should be_true
    end
  end
end
