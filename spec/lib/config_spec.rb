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
      it "should raise error if no config set" do
        lambda do
          Doorkeeper.validate_configuration
        end.should raise_error "You have to specify doorkeeper configuration"
      end

      it "should raise error if no resource_owner_authenticator block has been set" do
        Doorkeeper.configure do
        end
        lambda do
          Doorkeeper.validate_configuration
        end.should raise_error "You have to specify resource_owner_authenticator block"
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
  end
end
