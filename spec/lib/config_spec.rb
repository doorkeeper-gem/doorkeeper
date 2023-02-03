# frozen_string_literal: true

require "spec_helper"

RSpec.describe Doorkeeper::Config do
  subject(:config) { Doorkeeper.config }

  describe "resource_owner_authenticator" do
    it "sets the block that is accessible via authenticate_resource_owner" do
      block = proc {}
      Doorkeeper.configure do
        orm DOORKEEPER_ORM
        resource_owner_authenticator(&block)
      end

      expect(config.authenticate_resource_owner).to eq(block)
    end

    it "prints warning message by default" do
      Doorkeeper.configure do
        orm DOORKEEPER_ORM
      end

      expect(Rails.logger).to receive(:warn).with(
        I18n.t("doorkeeper.errors.messages.resource_owner_authenticator_not_configured"),
      )
      config.authenticate_resource_owner.call(nil)
    end
  end

  describe "resource_owner_from_credentials" do
    it "sets the block that is accessible via authenticate_resource_owner" do
      block = proc {}
      Doorkeeper.configure do
        orm DOORKEEPER_ORM
        resource_owner_from_credentials(&block)
      end

      expect(config.resource_owner_from_credentials).to eq(block)
    end

    it "prints warning message by default" do
      Doorkeeper.configure do
        orm DOORKEEPER_ORM
      end

      expect(Rails.logger).to receive(:warn).with(
        I18n.t("doorkeeper.errors.messages.credential_flow_not_configured"),
      )
      config.resource_owner_from_credentials.call(nil)
    end
  end

  describe "setup_orm" do
    it "adds specific error message to NameError exception" do
      expect do
        Doorkeeper.configure { orm "hibernate" }
        Doorkeeper.setup
      end.to raise_error(NameError, /ORM adapter not found \(hibernate\)/)
    end

    it "does not change other exceptions" do
      allow(Doorkeeper).to receive(:setup_orm_adapter) { raise NoMethodError }

      expect do
        Doorkeeper.configure { orm "hibernate" }
        Doorkeeper.setup
      end.to raise_error(NoMethodError)
    end
  end

  describe "admin_authenticator" do
    it "sets the block that is accessible via authenticate_admin" do
      default_behaviour = "default behaviour"
      allow(described_class).to receive(:head).and_return(default_behaviour)

      Doorkeeper.configure do
        orm DOORKEEPER_ORM
      end

      expect(config.authenticate_admin.call({})).to eq(default_behaviour)
    end

    it "could be customized with a block" do
      block = proc {}
      Doorkeeper.configure do
        orm DOORKEEPER_ORM
        admin_authenticator(&block)
      end

      expect(config.authenticate_admin).to eq(block)
    end
  end

  describe "access_token_expires_in" do
    it "has 2 hours by default" do
      expect(config.access_token_expires_in).to eq(2.hours)
    end

    it "can change the value" do
      Doorkeeper.configure do
        orm DOORKEEPER_ORM
        access_token_expires_in 4.hours
      end
      expect(config.access_token_expires_in).to eq(4.hours)
    end

    it "can be set to nil" do
      Doorkeeper.configure do
        orm DOORKEEPER_ORM
        access_token_expires_in nil
      end

      expect(config.access_token_expires_in).to be_nil
    end
  end

  describe "scopes" do
    it "has default scopes" do
      Doorkeeper.configure do
        orm DOORKEEPER_ORM
        default_scopes :public
      end

      expect(config.default_scopes).to include("public")
    end

    it "has optional scopes" do
      Doorkeeper.configure do
        orm DOORKEEPER_ORM
        optional_scopes :write, :update
      end

      expect(config.optional_scopes).to include("write", "update")
    end

    it "has all scopes" do
      Doorkeeper.configure do
        orm DOORKEEPER_ORM
        default_scopes :normal
        optional_scopes :admin
      end

      expect(config.scopes).to include("normal", "admin")
    end
  end

  describe "scopes_by_grant_type" do
    it "is {} by default" do
      expect(config.scopes_by_grant_type).to eq({})
    end

    it "has hash value" do
      hash = {}
      Doorkeeper.configure do
        orm DOORKEEPER_ORM
        scopes_by_grant_type hash
      end

      expect(config.scopes_by_grant_type).to eq(hash)
    end
  end

  describe "use_refresh_token" do
    it "is false by default" do
      expect(config.refresh_token_enabled?).to eq(false)
    end

    it "can change the value" do
      Doorkeeper.configure do
        orm DOORKEEPER_ORM
        use_refresh_token
      end

      expect(config.refresh_token_enabled?).to eq(true)
    end

    it "can accept a boolean parameter" do
      Doorkeeper.configure do
        orm DOORKEEPER_ORM
        use_refresh_token false
      end

      expect(config.refresh_token_enabled?).to eq(false)
    end

    it "can accept a block parameter" do
      Doorkeeper.configure do
        orm DOORKEEPER_ORM
        use_refresh_token { |_context| nil }
      end

      expect(config.refresh_token_enabled?).to be_a(Proc)
    end

    it "does not includes 'refresh_token' in token_grant_flows" do
      expect(config.token_grant_flows).not_to include Doorkeeper::GrantFlow.get("refresh_token")
    end

    context "when enabled" do
      before do
        Doorkeeper.configure do
          orm DOORKEEPER_ORM
          use_refresh_token
        end
      end

      it "includes 'refresh_token' in token_grant_flows" do
        expect(config.token_grant_flows).to include Doorkeeper::GrantFlow.get("refresh_token")
      end
    end
  end

  describe "token_reuse_limit" do
    it "is 100 by default" do
      expect(config.token_reuse_limit).to eq(100)
    end

    it "can change the value" do
      Doorkeeper.configure do
        orm DOORKEEPER_ORM
        token_reuse_limit 90
      end

      expect(config.token_reuse_limit).to eq(90)
    end

    it "sets the value to 100 if invalid value is being set" do
      expect(Rails.logger).to receive(:warn).with(/will be set to default 100/)

      Doorkeeper.configure do
        orm DOORKEEPER_ORM
        reuse_access_token
        token_reuse_limit 110
      end

      expect(config.token_reuse_limit).to eq(100)
    end
  end

  describe "enforce_configured_scopes" do
    it "is false by default" do
      expect(config.enforce_configured_scopes?).to eq(false)
    end

    it "can change the value" do
      Doorkeeper.configure do
        orm DOORKEEPER_ORM
        enforce_configured_scopes
      end

      expect(config.enforce_configured_scopes?).to eq(true)
    end
  end

  describe 'use_url_path_for_native_authorization' do
    around(:each) do |example|
      Doorkeeper.configure do
        orm DOORKEEPER_ORM
        use_url_path_for_native_authorization
      end

      Rails.application.reload_routes!

      subject { Doorkeeper.configuration }

      example.run

      Doorkeeper.configure do
        orm DOORKEEPER_ORM
      end

      Rails.application.reload_routes!
    end

    it 'sets the native authorization code route /:code' do
      expect(subject.native_authorization_code_route).to eq('/:code')
    end
  end

  describe "client_credentials" do
    it "has defaults order" do
      expect(config.client_credentials_methods)
        .to eq(%i[from_basic from_params])
    end

    it "can change the value" do
      Doorkeeper.configure do
        orm DOORKEEPER_ORM
        client_credentials :from_digest, :from_params
      end

      expect(config.client_credentials_methods)
        .to eq(%i[from_digest from_params])
    end
  end

  describe "force_ssl_in_redirect_uri" do
    it "is true by default in non-development environments" do
      expect(config.force_ssl_in_redirect_uri).to eq(true)
    end

    it "can change the value" do
      Doorkeeper.configure do
        orm DOORKEEPER_ORM
        force_ssl_in_redirect_uri(false)
      end

      expect(config.force_ssl_in_redirect_uri).to eq(false)
    end

    it "can be a callable object" do
      block = proc { false }
      Doorkeeper.configure do
        orm DOORKEEPER_ORM
        force_ssl_in_redirect_uri(&block)
      end

      expect(config.force_ssl_in_redirect_uri).to eq(block)
      expect(config.force_ssl_in_redirect_uri.call).to eq(false)
    end
  end

  describe "access_token_methods" do
    it "has defaults order" do
      expect(config.access_token_methods)
        .to eq(%i[from_bearer_authorization from_access_token_param from_bearer_param])
    end

    it "can change the value" do
      Doorkeeper.configure do
        orm DOORKEEPER_ORM
        access_token_methods :from_access_token_param, :from_bearer_param
      end

      expect(config.access_token_methods)
        .to eq(%i[from_access_token_param from_bearer_param])
    end
  end

  describe "forbid_redirect_uri" do
    it "is false by default" do
      expect(config.forbid_redirect_uri.call(URI.parse("https://localhost"))).to eq(false)
    end

    it "can be a callable object" do
      block = proc { true }
      Doorkeeper.configure do
        orm DOORKEEPER_ORM
        forbid_redirect_uri(&block)
      end

      expect(config.forbid_redirect_uri).to eq(block)
      expect(config.forbid_redirect_uri.call).to eq(true)
    end
  end

  describe "enable_application_owner" do
    it "is disabled by default" do
      expect(Doorkeeper.config.enable_application_owner?).not_to be(true)
    end

    context "when enabled without confirmation" do
      class ApplicationWithOwner < ActiveRecord::Base
        include Doorkeeper::Orm::ActiveRecord::Mixins::Application
      end

      before do
        Doorkeeper.configure do
          orm DOORKEEPER_ORM
          enable_application_owner

          application_class "ApplicationWithOwner"
        end

        Doorkeeper.run_orm_hooks
      end

      it "adds support for application owner" do
        instance = ApplicationWithOwner.new(FactoryBot.attributes_for(:application))

        expect(instance).to respond_to :owner
        expect(instance).to be_valid
      end

      it "Doorkeeper.configuration.confirm_application_owner? returns false" do
        expect(Doorkeeper.config.confirm_application_owner?).not_to be(true)
      end
    end

    context "when enabled with confirmation set to true" do
      class ApplicationWithOwner < ActiveRecord::Base
        include Doorkeeper::Orm::ActiveRecord::Mixins::Application
      end

      before do
        Doorkeeper.configure do
          orm DOORKEEPER_ORM
          enable_application_owner confirmation: true

          application_class "ApplicationWithOwner"
        end

        Doorkeeper.run_orm_hooks
      end

      it "adds support for application owner" do
        instance = ApplicationWithOwner.new(FactoryBot.attributes_for(:application))

        expect(instance).to respond_to :owner
        expect(instance).not_to be_valid
        expect(instance.errors[:owner]).to be_present
      end

      it "Doorkeeper.configuration.confirm_application_owner? returns true" do
        expect(Doorkeeper.config.confirm_application_owner?).to be(true)
      end
    end
  end

  describe "realm" do
    it "is 'Doorkeeper' by default" do
      expect(Doorkeeper.config.realm).to eq("Doorkeeper")
    end

    it "can change the value" do
      Doorkeeper.configure do
        orm DOORKEEPER_ORM
        realm "Example"
      end

      expect(config.realm).to eq("Example")
    end
  end

  describe "grant_flows" do
    it "is set to all grant flows by default" do
      expect(Doorkeeper.config.grant_flows)
        .to eq(%w[authorization_code client_credentials])
    end

    it "can change the value" do
      Doorkeeper.configure do
        orm DOORKEEPER_ORM
        grant_flows %w[authorization_code implicit]
      end

      expect(config.grant_flows).to eq %w[authorization_code implicit]
    end

    context "when including 'authorization_code'" do
      before do
        Doorkeeper.configure do
          orm DOORKEEPER_ORM
          grant_flows ["authorization_code"]
        end
      end

      it "includes 'authorization_code' in authorization_response_flows" do
        expect(config.authorization_response_flows).to include Doorkeeper::GrantFlow.get("authorization_code")
      end

      it "includes 'authorization_code' in token_grant_flows" do
        expect(config.token_grant_flows).to include Doorkeeper::GrantFlow.get("authorization_code")
      end
    end

    context "when including 'implicit'" do
      before do
        Doorkeeper.configure do
          orm DOORKEEPER_ORM
          grant_flows ["implicit"]
        end
      end

      it "includes 'implicit' in authorization_response_flows" do
        expect(config.authorization_response_flows).to include Doorkeeper::GrantFlow.get("implicit")
      end
    end

    context "when including 'password'" do
      before do
        Doorkeeper.configure do
          orm DOORKEEPER_ORM
          grant_flows ["password"]
        end
      end

      it "includes 'password' in token_grant_flows" do
        expect(config.token_grant_flows).to include Doorkeeper::GrantFlow.get("password")
      end
    end

    context "when including 'client_credentials'" do
      before do
        Doorkeeper.configure do
          orm DOORKEEPER_ORM
          grant_flows ["client_credentials"]
        end
      end

      it "includes 'client_credentials' in token_grant_flows" do
        expect(config.token_grant_flows).to include Doorkeeper::GrantFlow.get("client_credentials")
      end
    end
  end

  describe "access_token_generator" do
    it "is 'Doorkeeper::OAuth::Helpers::UniqueToken' by default" do
      expect(Doorkeeper.configuration.access_token_generator).to(
        eq("Doorkeeper::OAuth::Helpers::UniqueToken"),
      )
    end

    it "can change the value" do
      Doorkeeper.configure do
        orm DOORKEEPER_ORM
        access_token_generator "Example"
      end
      expect(config.access_token_generator).to eq("Example")
    end
  end

  describe "custom_access_token_attributes" do
    it "is '[]' by default" do
      expect(Doorkeeper.configuration.custom_access_token_attributes).to(eq([]))
    end

    it "can change the value" do
      Doorkeeper.configure do
        orm DOORKEEPER_ORM
        custom_access_token_attributes [:added_field_1, :added_field_2]
      end
      expect(config.custom_access_token_attributes).to eq([:added_field_1, :added_field_2])
    end
  end

  describe "application_secret_generator" do
    it "is 'Doorkeeper::OAuth::Helpers::UniqueToken' by default" do
      expect(Doorkeeper.configuration.application_secret_generator).to(
        eq("Doorkeeper::OAuth::Helpers::UniqueToken"),
      )
    end

    it "can change the value" do
      Doorkeeper.configure do
        orm DOORKEEPER_ORM
        application_secret_generator "Example"
      end
      expect(config.application_secret_generator).to eq("Example")
    end
  end

  describe "default_generator_method" do
    it "is :urlsafe_base64 by default" do
      expect(Doorkeeper.configuration.default_generator_method)
        .to eq(:urlsafe_base64)
    end

    it "can change the value" do
      Doorkeeper.configure do
        orm DOORKEEPER_ORM
        default_generator_method :hex
      end

      expect(config.default_generator_method).to eq(:hex)
    end
  end

  describe "base_controller" do
    context "when default value set" do
      it { expect(Doorkeeper.configuration.base_controller).to be_an_instance_of(Proc) }

      it "resolves to a ApplicationController::Base in default mode" do
        expect(Doorkeeper.configuration.resolve_controller(:base))
          .to eq(ActionController::Base)
      end

      it "resolves to a ApplicationController::API in api_only mode" do
        Doorkeeper.configure do
          orm DOORKEEPER_ORM
          api_only
        end

        expect(Doorkeeper.configuration.resolve_controller(:base))
          .to eq(ActionController::API)
      end
    end

    context "when custom value set" do
      before do
        Doorkeeper.configure do
          orm DOORKEEPER_ORM
          base_controller "ApplicationController"
        end
      end

      it { expect(Doorkeeper.config.base_controller).to eq("ApplicationController") }
    end
  end

  describe "base_metal_controller" do
    context "when default value set" do
      it { expect(Doorkeeper.config.base_metal_controller).to eq("ActionController::API") }
    end

    context "when custom value set" do
      before do
        Doorkeeper.configure do
          orm DOORKEEPER_ORM
          base_metal_controller { "ApplicationController" }
        end
      end

      it { expect(Doorkeeper.configuration.resolve_controller(:base_metal)).to eq(ApplicationController) }
    end
  end

  if DOORKEEPER_ORM == :active_record
    class FakeCustomModel < ::ActiveRecord::Base
    end

    describe "access_token_class" do
      it "uses default doorkeeper value" do
        expect(config.access_token_class).to eq("Doorkeeper::AccessToken")
        expect(config.access_token_model).to be(Doorkeeper::AccessToken)
      end

      it "can change the value" do
        Doorkeeper.configure do
          orm DOORKEEPER_ORM
          access_token_class "FakeCustomModel"
        end

        expect(config.access_token_class).to eq("FakeCustomModel")
        expect(config.access_token_model).to be(FakeCustomModel)
      end
    end

    describe "access_grant_class" do
      it "uses default doorkeeper value" do
        expect(config.access_grant_class).to eq("Doorkeeper::AccessGrant")
        expect(config.access_grant_model).to be(Doorkeeper::AccessGrant)
      end

      it "can change the value" do
        Doorkeeper.configure do
          orm DOORKEEPER_ORM
          access_grant_class "FakeCustomModel"
        end

        expect(config.access_grant_class).to eq("FakeCustomModel")
        expect(config.access_grant_model).to be(FakeCustomModel)
      end
    end

    describe "application_class" do
      it "uses default doorkeeper value" do
        expect(config.application_class).to eq("Doorkeeper::Application")
        expect(config.application_model).to be(Doorkeeper::Application)
      end

      it "can change the value" do
        Doorkeeper.configure do
          orm DOORKEEPER_ORM
          application_class "FakeCustomModel"
        end

        expect(config.application_class).to eq("FakeCustomModel")
        expect(config.application_model).to be(FakeCustomModel)
      end
    end
  end

  describe "api_only" do
    it "is false by default" do
      expect(config.api_only).to eq(false)
    end

    it "can change the value" do
      Doorkeeper.configure do
        orm DOORKEEPER_ORM
        api_only
      end

      expect(config.api_only).to eq(true)
    end
  end

  describe "token_lookup_batch_size" do
    it "uses default doorkeeper value" do
      expect(config.token_lookup_batch_size).to eq(10_000)
    end

    it "can change the value" do
      Doorkeeper.configure do
        orm DOORKEEPER_ORM
        token_lookup_batch_size 100_000
      end

      expect(config.token_lookup_batch_size).to eq(100_000)
    end
  end

  describe "strict_content_type" do
    it "is false by default" do
      expect(config.enforce_content_type).to eq(false)
    end

    it "can change the value" do
      Doorkeeper.configure do
        orm DOORKEEPER_ORM
        enforce_content_type
      end

      expect(config.enforce_content_type).to eq(true)
    end
  end

  describe "handle_auth_errors" do
    it "is set to render by default" do
      expect(Doorkeeper.config.handle_auth_errors).to eq(:render)
    end

    it "can change the value" do
      Doorkeeper.configure do
        orm DOORKEEPER_ORM
        handle_auth_errors :raise
      end
      expect(config.handle_auth_errors).to eq(:raise)
    end
  end

  describe "token_secret_strategy" do
    it "is plain by default" do
      expect(config.token_secret_strategy).to eq(Doorkeeper::SecretStoring::Plain)
      expect(config.token_secret_fallback_strategy).to eq(nil)
    end

    context "when provided" do
      before do
        Doorkeeper.configure do
          orm DOORKEEPER_ORM
          hash_token_secrets
        end
      end

      it "will enable hashing for applications" do
        expect(config.token_secret_strategy).to eq(Doorkeeper::SecretStoring::Sha256Hash)
        expect(config.token_secret_fallback_strategy).to eq(nil)
      end
    end

    context "when manually provided with invalid constant" do
      it "raises an exception" do
        expect do
          Doorkeeper.configure do
            orm DOORKEEPER_ORM
            hash_token_secrets using: "does not exist"
          end
        end.to raise_error(NameError)
      end
    end

    context "when manually provided with invalid option" do
      it "raises an exception" do
        expect do
          Doorkeeper.configure do
            orm DOORKEEPER_ORM
            hash_token_secrets using: "Doorkeeper::SecretStoring::BCrypt"
          end
        end.to raise_error(
          ArgumentError,
          /can only be used for storing application secrets/,
        )
      end
    end

    context "when provided with fallback" do
      before do
        Doorkeeper.configure do
          orm DOORKEEPER_ORM
          hash_token_secrets fallback: :plain
        end
      end

      it "will enable hashing for applications" do
        expect(config.token_secret_strategy).to eq(Doorkeeper::SecretStoring::Sha256Hash)
        expect(config.token_secret_fallback_strategy).to eq(Doorkeeper::SecretStoring::Plain)
      end
    end

    describe "hash_token_secrets together with reuse_access_token" do
      it "will disable reuse_access_token" do
        expect(Rails.logger).to receive(:warn).with(/reuse_access_token will be disabled/)

        Doorkeeper.configure do
          orm DOORKEEPER_ORM
          reuse_access_token
          hash_token_secrets
        end

        expect(config.reuse_access_token).to eq(false)
      end
    end
  end

  describe "application_secret_strategy" do
    it "is plain by default" do
      expect(config.application_secret_strategy).to eq(Doorkeeper::SecretStoring::Plain)
      expect(config.application_secret_fallback_strategy).to eq(nil)
    end

    context "when provided" do
      before do
        Doorkeeper.configure do
          orm DOORKEEPER_ORM
          hash_application_secrets
        end
      end

      it "will enable hashing for applications" do
        expect(config.application_secret_strategy).to eq(Doorkeeper::SecretStoring::Sha256Hash)
        expect(config.application_secret_fallback_strategy).to eq(nil)
      end
    end

    context "when manually provided with invalid constant" do
      it "raises an exception" do
        expect do
          Doorkeeper.configure do
            orm DOORKEEPER_ORM
            hash_application_secrets using: "does not exist"
          end
        end.to raise_error(NameError)
      end
    end

    context "when provided with fallback" do
      before do
        Doorkeeper.configure do
          orm DOORKEEPER_ORM
          hash_application_secrets fallback: :plain
        end
      end

      it "will enable hashing for applications" do
        expect(config.application_secret_strategy).to eq(Doorkeeper::SecretStoring::Sha256Hash)
        expect(config.application_secret_fallback_strategy).to eq(Doorkeeper::SecretStoring::Plain)
      end
    end
  end

  describe "options deprecation" do
    it "prints a warning message when an option is deprecated" do
      expect(Kernel).to receive(:warn).with(
        /\[DOORKEEPER\] native_redirect_uri has been deprecated and will soon be removed/,
      )
      Doorkeeper.configure do
        orm DOORKEEPER_ORM
        native_redirect_uri "urn:ietf:wg:oauth:2.0:oob"
      end
    end
  end
end
