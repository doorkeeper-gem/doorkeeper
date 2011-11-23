require 'spec_helper'

module Doorkeeper
  describe Config do
    before :all do
      @old_config = Doorkeeper.class_variable_get(:@@config)
    end

    after :all do
      Doorkeeper.class_variable_set(:@@config, @old_config)
    end

    before :each do
      Doorkeeper.remove_class_variable(:@@config) if Doorkeeper.class_variable_defined?(:@@config)
    end

    describe "validation" do
      it "raises an error if no config set" do
        lambda do
          Doorkeeper.validate_configuration
        end.should raise_error "You have to specify doorkeeper configuration"
      end

      it "raises an error if no resource_owner_authenticator block has been set" do
        Doorkeeper.configure do
        end
        lambda do
          Doorkeeper.validate_configuration
        end.should raise_error "You have to specify resource_owner_authenticator block for doorkeeper"
      end

      it "does not raise an error if all configs have been set" do
        Doorkeeper.configure do
          resource_owner_authenticator do end
        end
        Doorkeeper.validate_configuration.should be_true
      end
    end

    describe "resource_owner_authenticator" do
      it "sets the block that is accessible via authenticate_resource_owner" do
        block = proc do end
        config = Config.new do
          resource_owner_authenticator &block
        end
        config.authenticate_resource_owner.should == block
      end
    end

    describe "admin_authenticator" do
      it "sets the block that is accessible via authenticate_admin" do
        block = proc do end
        config = Config.new do
          admin_authenticator &block
        end
        config.authenticate_admin.should == block
      end
    end
  end
end
