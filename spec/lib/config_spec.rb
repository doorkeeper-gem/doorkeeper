require 'spec_helper_integration'

describe Doorkeeper, "configuration" do
  subject { Doorkeeper.configuration }

  describe "resource_owner_authenticator" do
    it "sets the block that is accessible via authenticate_resource_owner" do
      block = proc do end
      Doorkeeper.configure do
        orm DOORKEEPER_ORM
        resource_owner_authenticator &block
      end
      subject.authenticate_resource_owner.should == block
    end
  end

  describe "admin_authenticator" do
    it "sets the block that is accessible via authenticate_admin" do
      block = proc do end
      Doorkeeper.configure do
        orm DOORKEEPER_ORM
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
        orm DOORKEEPER_ORM
        access_token_expires_in 4.hours
      end
      subject.access_token_expires_in.should == 4.hours
    end

    it "can be set to nil" do
      Doorkeeper.configure do
        orm DOORKEEPER_ORM
        access_token_expires_in nil
      end
      subject.access_token_expires_in.should be_nil
    end
  end

  describe "scopes" do
    it "has default scopes" do
      Doorkeeper.configure {
        orm DOORKEEPER_ORM
        default_scopes :public
      }
      subject.default_scopes.should include('public')
    end

    it 'has optional scopes' do
      Doorkeeper.configure {
        orm DOORKEEPER_ORM
        optional_scopes :write, :update
      }
      subject.optional_scopes.should include('write', 'update')
    end

    it 'has all scopes' do
      Doorkeeper.configure do
        orm DOORKEEPER_ORM
        default_scopes  :normal
        optional_scopes :admin
      end
      subject.scopes.should include('normal', 'admin')
    end
  end

  describe "use_refresh_token" do
    it "is false by default" do
      subject.refresh_token_enabled?.should be_false
    end

    it "can change the value" do
      Doorkeeper.configure {
        orm DOORKEEPER_ORM
        use_refresh_token
      }
      subject.refresh_token_enabled?.should be_true
    end
  end

  describe 'client_credentials' do
    it 'has defaults order' do
      subject.client_credentials_methods.should == [:from_basic, :from_params]
    end

    it "can change the value" do
      Doorkeeper.configure {
        orm DOORKEEPER_ORM
        client_credentials :from_digest, :from_params
      }
      subject.client_credentials_methods.should == [:from_digest, :from_params]
    end
  end

  describe 'access_token_credentials' do
    it 'has defaults order' do
      subject.access_token_methods.should == [:from_bearer_authorization, :from_access_token_param, :from_bearer_param]
    end

    it "can change the value" do
      Doorkeeper.configure {
        orm DOORKEEPER_ORM
        access_token_methods :from_access_token_param, :from_bearer_param
      }
      subject.access_token_methods.should == [:from_access_token_param, :from_bearer_param]
    end
  end

  describe "enable_application_owner" do
    it "is disabled by default" do
      Doorkeeper.configuration.enable_application_owner?.should_not be_true
    end

    context "when enabled without confirmation" do
      before do
        Doorkeeper.configure do
          orm DOORKEEPER_ORM
          enable_application_owner
        end
      end
      it "adds support for application owner" do
        Doorkeeper::Application.new.should respond_to :owner
      end
      it "Doorkeeper.configuration.confirm_application_owner? returns false" do
        Doorkeeper.configuration.confirm_application_owner?.should_not be_true
      end
    end

    context "when enabled with confirmation set to true" do
      before do
        Doorkeeper.configure do
          orm DOORKEEPER_ORM
          enable_application_owner :confirmation => true
        end
      end
      it "adds support for application owner" do
        Doorkeeper::Application.new.should respond_to :owner
      end
      it "Doorkeeper.configuration.confirm_application_owner? returns true" do
        Doorkeeper.configuration.confirm_application_owner?.should be_true
      end
    end

  end

  it 'raises an exception when configuration is not set' do
    old_config = Doorkeeper.configuration
    Doorkeeper.module_eval do
      @config = nil
    end

    expect do
      Doorkeeper.configuration
    end.to raise_error Doorkeeper::MissingConfiguration

    Doorkeeper.module_eval do
      @config = old_config
    end
  end
end
