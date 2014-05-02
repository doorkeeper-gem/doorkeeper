require 'spec_helper_integration'

describe Doorkeeper, 'configuration' do
  subject { Doorkeeper.configuration }

  describe 'resource_owner_authenticator' do
    it 'sets the block that is accessible via authenticate_resource_owner' do
      block = proc {}
      Doorkeeper.configure do
        orm DOORKEEPER_ORM
        resource_owner_authenticator &block
      end
      expect(subject.authenticate_resource_owner).to eq(block)
    end
  end

  describe 'admin_authenticator' do
    it 'sets the block that is accessible via authenticate_admin' do
      block = proc {}
      Doorkeeper.configure do
        orm DOORKEEPER_ORM
        admin_authenticator &block
      end
      expect(subject.authenticate_admin).to eq(block)
    end
  end

  describe 'access_token_expires_in' do
    it 'has 2 hours by default' do
      expect(subject.access_token_expires_in).to eq(2.hours)
    end

    it 'can change the value' do
      Doorkeeper.configure do
        orm DOORKEEPER_ORM
        access_token_expires_in 4.hours
      end
      expect(subject.access_token_expires_in).to eq(4.hours)
    end

    it 'can be set to nil' do
      Doorkeeper.configure do
        orm DOORKEEPER_ORM
        access_token_expires_in nil
      end
      expect(subject.access_token_expires_in).to be_nil
    end
  end

  describe 'scopes' do
    it 'has default scopes' do
      Doorkeeper.configure do
        orm DOORKEEPER_ORM
        default_scopes :public
      end
      expect(subject.default_scopes).to include('public')
    end

    it 'has optional scopes' do
      Doorkeeper.configure do
        orm DOORKEEPER_ORM
        optional_scopes :write, :update
      end
      expect(subject.optional_scopes).to include('write', 'update')
    end

    it 'has all scopes' do
      Doorkeeper.configure do
        orm DOORKEEPER_ORM
        default_scopes  :normal
        optional_scopes :admin
      end
      expect(subject.scopes).to include('normal', 'admin')
    end
  end

  describe 'use_refresh_token' do
    it 'is false by default' do
      expect(subject.refresh_token_enabled?).to be_false
    end

    it 'can change the value' do
      Doorkeeper.configure do
        orm DOORKEEPER_ORM
        use_refresh_token
      end
      expect(subject.refresh_token_enabled?).to be_true
    end
  end

  describe 'client_credentials' do
    it 'has defaults order' do
      expect(subject.client_credentials_methods).to eq([:from_basic, :from_params])
    end

    it 'can change the value' do
      Doorkeeper.configure do
        orm DOORKEEPER_ORM
        client_credentials :from_digest, :from_params
      end
      expect(subject.client_credentials_methods).to eq([:from_digest, :from_params])
    end
  end

  describe 'access_token_credentials' do
    it 'has defaults order' do
      expect(subject.access_token_methods).to eq([:from_bearer_authorization, :from_access_token_param, :from_bearer_param])
    end

    it 'can change the value' do
      Doorkeeper.configure do
        orm DOORKEEPER_ORM
        access_token_methods :from_access_token_param, :from_bearer_param
      end
      expect(subject.access_token_methods).to eq([:from_access_token_param, :from_bearer_param])
    end
  end

  describe 'enable_application_owner' do
    it 'is disabled by default' do
      expect(Doorkeeper.configuration.enable_application_owner?).not_to be_true
    end

    context 'when enabled without confirmation' do
      before do
        Doorkeeper.configure do
          orm DOORKEEPER_ORM
          enable_application_owner
        end
      end
      it 'adds support for application owner' do
        expect(Doorkeeper::Application.new).to respond_to :owner
      end
      it 'Doorkeeper.configuration.confirm_application_owner? returns false' do
        expect(Doorkeeper.configuration.confirm_application_owner?).not_to be_true
      end
    end

    context 'when enabled with confirmation set to true' do
      before do
        Doorkeeper.configure do
          orm DOORKEEPER_ORM
          enable_application_owner confirmation: true
        end
      end
      it 'adds support for application owner' do
        expect(Doorkeeper::Application.new).to respond_to :owner
      end
      it 'Doorkeeper.configuration.confirm_application_owner? returns true' do
        expect(Doorkeeper.configuration.confirm_application_owner?).to be_true
      end
    end
  end

  describe 'wildcard_redirect_uri' do
    it 'is disabled by default' do
      Doorkeeper.configuration.wildcard_redirect_uri.should be_false
    end
  end

  describe 'realm' do
    it 'is \'Doorkeeper\' by default' do
      expect(Doorkeeper.configuration.realm).to eq('Doorkeeper')
    end

    it 'can change the value' do
      Doorkeeper.configure do
        orm DOORKEEPER_ORM
        realm 'Example'
      end
      expect(subject.realm).to eq('Example')
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
