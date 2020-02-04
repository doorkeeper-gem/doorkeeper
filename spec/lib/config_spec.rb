# frozen_string_literal: true

require "spec_helper"

describe Doorkeeper, "configuration" do
  subject { Doorkeeper.configuration }

  describe "resource_owner_authenticator" do
    it "sets the block that is accessible via authenticate_resource_owner" do
      block = proc {}
      Doorkeeper.configure do
        orm DOORKEEPER_ORM
        resource_owner_authenticator(&block)
      end

      expect(subject.authenticate_resource_owner).to eq(block)
    end

    it "prints warning message by default" do
      Doorkeeper.configure do
        orm DOORKEEPER_ORM
      end

      expect(Rails.logger).to receive(:warn).with(
        I18n.t("doorkeeper.errors.messages.resource_owner_authenticator_not_configured"),
      )
      subject.authenticate_resource_owner.call(nil)
    end
  end

  describe "resource_owner_from_credentials" do
    it "sets the block that is accessible via authenticate_resource_owner" do
      block = proc {}
      Doorkeeper.configure do
        orm DOORKEEPER_ORM
        resource_owner_from_credentials(&block)
      end

      expect(subject.resource_owner_from_credentials).to eq(block)
    end

    it "prints warning message by default" do
      Doorkeeper.configure do
        orm DOORKEEPER_ORM
      end

      expect(Rails.logger).to receive(:warn).with(
        I18n.t("doorkeeper.errors.messages.credential_flow_not_configured"),
      )
      subject.resource_owner_from_credentials.call(nil)
    end
  end

  describe "setup_orm_adapter" do
    it "adds specific error message to NameError exception" do
      expect do
        Doorkeeper.configure { orm "hibernate" }
      end.to raise_error(NameError, /ORM adapter not found \(hibernate\)/)
    end

    it "does not change other exceptions" do
      allow(Doorkeeper).to receive(:setup_orm_adapter) { raise NoMethodError }

      expect do
        Doorkeeper.configure { orm "hibernate" }
      end.to raise_error(NoMethodError)
    end
  end

  describe "admin_authenticator" do
    it "sets the block that is accessible via authenticate_admin" do
      default_behaviour = "default behaviour"
      allow(Doorkeeper::Config).to receive(:head).and_return(default_behaviour)

      Doorkeeper.configure do
        orm DOORKEEPER_ORM
      end

      expect(subject.authenticate_admin.call({})).to eq(default_behaviour)
    end

    it "sets the block that is accessible via authenticate_admin" do
      block = proc {}
      Doorkeeper.configure do
        orm DOORKEEPER_ORM
        admin_authenticator(&block)
      end

      expect(subject.authenticate_admin).to eq(block)
    end
  end

  describe "access_token_expires_in" do
    it "has 2 hours by default" do
      expect(subject.access_token_expires_in).to eq(2.hours)
    end

    it "can change the value" do
      Doorkeeper.configure do
        orm DOORKEEPER_ORM
        access_token_expires_in 4.hours
      end
      expect(subject.access_token_expires_in).to eq(4.hours)
    end

    it "can be set to nil" do
      Doorkeeper.configure do
        orm DOORKEEPER_ORM
        access_token_expires_in nil
      end

      expect(subject.access_token_expires_in).to be_nil
    end
  end

  describe "scopes" do
    it "has default scopes" do
      Doorkeeper.configure do
        orm DOORKEEPER_ORM
        default_scopes :public
      end

      expect(subject.default_scopes).to include("public")
    end

    it "has optional scopes" do
      Doorkeeper.configure do
        orm DOORKEEPER_ORM
        optional_scopes :write, :update
      end

      expect(subject.optional_scopes).to include("write", "update")
    end

    it "has all scopes" do
      Doorkeeper.configure do
        orm DOORKEEPER_ORM
        default_scopes :normal
        optional_scopes :admin
      end

      expect(subject.scopes).to include("normal", "admin")
    end
  end

  describe "scopes_by_grant_type" do
    it "is {} by default" do
      expect(subject.scopes_by_grant_type).to eq({})
    end

    it "has hash value" do
      hash = {}
      Doorkeeper.configure do
        orm DOORKEEPER_ORM
        scopes_by_grant_type hash
      end

      expect(subject.scopes_by_grant_type).to eq(hash)
    end
  end

  describe "use_refresh_token" do
    it "is false by default" do
      expect(subject.refresh_token_enabled?).to eq(false)
    end

    it "can change the value" do
      Doorkeeper.configure do
        orm DOORKEEPER_ORM
        use_refresh_token
      end

      expect(subject.refresh_token_enabled?).to eq(true)
    end

    it "can accept a boolean parameter" do
      Doorkeeper.configure do
        orm DOORKEEPER_ORM
        use_refresh_token false
      end

      expect(subject.refresh_token_enabled?).to eq(false)
    end

    it "can accept a block parameter" do
      Doorkeeper.configure do
        orm DOORKEEPER_ORM
        use_refresh_token { |_context| nil }
      end

      expect(subject.refresh_token_enabled?).to be_a(Proc)
    end

    it "does not includes 'refresh_token' in authorization_response_types" do
      expect(subject.token_grant_types).not_to include "refresh_token"
    end

    context "is enabled" do
      before do
        Doorkeeper.configure do
          orm DOORKEEPER_ORM
          use_refresh_token
        end
      end

      it "includes 'refresh_token' in authorization_response_types" do
        expect(subject.token_grant_types).to include "refresh_token"
      end
    end
  end

  describe "token_reuse_limit" do
    it "is 100 by default" do
      expect(subject.token_reuse_limit).to eq(100)
    end

    it "can change the value" do
      Doorkeeper.configure do
        token_reuse_limit 90
      end

      expect(subject.token_reuse_limit).to eq(90)
    end

    it "sets the value to 100 if invalid value is being set" do
      expect(Rails.logger).to receive(:warn).with(/will be set to default 100/)

      Doorkeeper.configure do
        reuse_access_token
        token_reuse_limit 110
      end

      expect(subject.token_reuse_limit).to eq(100)
    end
  end

  describe "enforce_configured_scopes" do
    it "is false by default" do
      expect(subject.enforce_configured_scopes?).to eq(false)
    end

    it "can change the value" do
      Doorkeeper.configure do
        orm DOORKEEPER_ORM
        enforce_configured_scopes
      end

      expect(subject.enforce_configured_scopes?).to eq(true)
    end
  end

  describe "client_credentials" do
    it "has defaults order" do
      expect(subject.client_credentials_methods)
        .to eq(%i[from_basic from_params])
    end

    it "can change the value" do
      Doorkeeper.configure do
        orm DOORKEEPER_ORM
        client_credentials :from_digest, :from_params
      end

      expect(subject.client_credentials_methods)
        .to eq(%i[from_digest from_params])
    end
  end

  describe "force_ssl_in_redirect_uri" do
    it "is true by default in non-development environments" do
      expect(subject.force_ssl_in_redirect_uri).to eq(true)
    end

    it "can change the value" do
      Doorkeeper.configure do
        orm DOORKEEPER_ORM
        force_ssl_in_redirect_uri(false)
      end

      expect(subject.force_ssl_in_redirect_uri).to eq(false)
    end

    it "can be a callable object" do
      block = proc { false }
      Doorkeeper.configure do
        orm DOORKEEPER_ORM
        force_ssl_in_redirect_uri(&block)
      end

      expect(subject.force_ssl_in_redirect_uri).to eq(block)
      expect(subject.force_ssl_in_redirect_uri.call).to eq(false)
    end
  end

  describe "access_token_methods" do
    it "has defaults order" do
      expect(subject.access_token_methods)
        .to eq(%i[from_bearer_authorization from_access_token_param from_bearer_param])
    end

    it "can change the value" do
      Doorkeeper.configure do
        orm DOORKEEPER_ORM
        access_token_methods :from_access_token_param, :from_bearer_param
      end

      expect(subject.access_token_methods)
        .to eq(%i[from_access_token_param from_bearer_param])
    end
  end

  describe "forbid_redirect_uri" do
    it "is false by default" do
      expect(subject.forbid_redirect_uri.call(URI.parse("https://localhost"))).to eq(false)
    end

    it "can be a callable object" do
      block = proc { true }
      Doorkeeper.configure do
        orm DOORKEEPER_ORM
        forbid_redirect_uri(&block)
      end

      expect(subject.forbid_redirect_uri).to eq(block)
      expect(subject.forbid_redirect_uri.call).to eq(true)
    end
  end

  describe "enable_application_owner" do
    it "is disabled by default" do
      expect(Doorkeeper.configuration.enable_application_owner?).not_to eq(true)
    end

    context "when enabled without confirmation" do
      before do
        Doorkeeper.configure do
          orm DOORKEEPER_ORM
          enable_application_owner
        end
      end

      it "adds support for application owner" do
        expect(Doorkeeper::Application.new).to respond_to :owner
      end

      it "Doorkeeper.configuration.confirm_application_owner? returns false" do
        expect(Doorkeeper.configuration.confirm_application_owner?).not_to eq(true)
      end
    end

    context "when enabled with confirmation set to true" do
      before do
        Doorkeeper.configure do
          orm DOORKEEPER_ORM
          enable_application_owner confirmation: true
        end
      end

      it "adds support for application owner" do
        expect(Doorkeeper::Application.new).to respond_to :owner
      end

      it "Doorkeeper.configuration.confirm_application_owner? returns true" do
        expect(Doorkeeper.configuration.confirm_application_owner?).to eq(true)
      end
    end
  end

  describe "realm" do
    it "is 'Doorkeeper' by default" do
      expect(Doorkeeper.configuration.realm).to eq("Doorkeeper")
    end

    it "can change the value" do
      Doorkeeper.configure do
        orm DOORKEEPER_ORM
        realm "Example"
      end

      expect(subject.realm).to eq("Example")
    end
  end

  describe "grant_flows" do
    it "is set to all grant flows by default" do
      expect(Doorkeeper.configuration.grant_flows)
        .to eq(%w[authorization_code client_credentials])
    end

    it "can change the value" do
      Doorkeeper.configure do
        orm DOORKEEPER_ORM
        grant_flows %w[authorization_code implicit]
      end

      expect(subject.grant_flows).to eq %w[authorization_code implicit]
    end

    context "when including 'authorization_code'" do
      before do
        Doorkeeper.configure do
          orm DOORKEEPER_ORM
          grant_flows ["authorization_code"]
        end
      end

      it "includes 'code' in authorization_response_types" do
        expect(subject.authorization_response_types).to include "code"
      end

      it "includes 'authorization_code' in token_grant_types" do
        expect(subject.token_grant_types).to include "authorization_code"
      end
    end

    context "when including 'implicit'" do
      before do
        Doorkeeper.configure do
          orm DOORKEEPER_ORM
          grant_flows ["implicit"]
        end
      end

      it "includes 'token' in authorization_response_types" do
        expect(subject.authorization_response_types).to include "token"
      end
    end

    context "when including 'password'" do
      before do
        Doorkeeper.configure do
          orm DOORKEEPER_ORM
          grant_flows ["password"]
        end
      end

      it "includes 'password' in token_grant_types" do
        expect(subject.token_grant_types).to include "password"
      end
    end

    context "when including 'client_credentials'" do
      before do
        Doorkeeper.configure do
          orm DOORKEEPER_ORM
          grant_flows ["client_credentials"]
        end
      end

      it "includes 'client_credentials' in token_grant_types" do
        expect(subject.token_grant_types).to include "client_credentials"
      end
    end
  end

  it "raises an exception when configuration is not set" do
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
      expect(subject.access_token_generator).to eq("Example")
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

      expect(subject.default_generator_method).to eq(:hex)
    end
  end

  describe "base_controller" do
    context "default" do
      it { expect(Doorkeeper.configuration.base_controller).to be_an_instance_of(Proc) }

      it "resolves to a ApplicationController::Base in default mode" do
        expect(Doorkeeper.configuration.resolve_controller(:base))
          .to eq(ActionController::Base)
      end

      it "resolves to a ApplicationController::API in api_only mode" do
        Doorkeeper.configure do
          api_only
        end

        expect(Doorkeeper.configuration.resolve_controller(:base))
          .to eq(ActionController::API)
      end
    end

    context "custom" do
      before do
        Doorkeeper.configure do
          orm DOORKEEPER_ORM
          base_controller "ApplicationController"
        end
      end

      it { expect(Doorkeeper.configuration.base_controller).to eq("ApplicationController") }
    end
  end

  describe "base_metal_controller" do
    context "default" do
      it { expect(Doorkeeper.configuration.base_metal_controller).to eq("ActionController::API") }
    end

    context "custom" do
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
    class FakeCustomModel; end

    describe "active_record_options" do
      let(:models) { [Doorkeeper::AccessGrant, Doorkeeper::AccessToken, Doorkeeper::Application] }

      before do
        models.each do |model|
          allow(model).to receive(:establish_connection).and_return(true)
        end
      end

      it "establishes connection for Doorkeeper models based on options" do
        models.each do |model|
          expect(model).to receive(:establish_connection)
        end

        expect(Kernel).to receive(:warn).with(
          /\[DOORKEEPER\] active_record_options has been deprecated and will soon be removed/,
        )

        Doorkeeper.configure do
          orm DOORKEEPER_ORM
          active_record_options(
            establish_connection: Rails.configuration.database_configuration[Rails.env],
          )
        end
      end
    end

    describe "access_token_class" do
      it "uses default doorkeeper value" do
        expect(subject.access_token_class).to eq("Doorkeeper::AccessToken")
        expect(subject.access_token_model).to be(Doorkeeper::AccessToken)
      end

      it "can change the value" do
        Doorkeeper.configure do
          orm DOORKEEPER_ORM
          access_token_class "FakeCustomModel"
        end

        expect(subject.access_token_class).to eq("FakeCustomModel")
        expect(subject.access_token_model).to be(FakeCustomModel)
      end
    end

    describe "access_grant_class" do
      it "uses default doorkeeper value" do
        expect(subject.access_grant_class).to eq("Doorkeeper::AccessGrant")
        expect(subject.access_grant_model).to be(Doorkeeper::AccessGrant)
      end

      it "can change the value" do
        Doorkeeper.configure do
          orm DOORKEEPER_ORM
          access_grant_class "FakeCustomModel"
        end

        expect(subject.access_grant_class).to eq("FakeCustomModel")
        expect(subject.access_grant_model).to be(FakeCustomModel)
      end
    end

    describe "application_class" do
      it "uses default doorkeeper value" do
        expect(subject.application_class).to eq("Doorkeeper::Application")
        expect(subject.application_model).to be(Doorkeeper::Application)
      end

      it "can change the value" do
        Doorkeeper.configure do
          orm DOORKEEPER_ORM
          application_class "FakeCustomModel"
        end

        expect(subject.application_class).to eq("FakeCustomModel")
        expect(subject.application_model).to be(FakeCustomModel)
      end
    end
  end

  describe "api_only" do
    it "is false by default" do
      expect(subject.api_only).to eq(false)
    end

    it "can change the value" do
      Doorkeeper.configure do
        orm DOORKEEPER_ORM
        api_only
      end

      expect(subject.api_only).to eq(true)
    end
  end

  describe "strict_content_type" do
    it "is false by default" do
      expect(subject.enforce_content_type).to eq(false)
    end

    it "can change the value" do
      Doorkeeper.configure do
        orm DOORKEEPER_ORM
        enforce_content_type
      end

      expect(subject.enforce_content_type).to eq(true)
    end
  end

  describe "handle_auth_errors" do
    it "is set to render by default" do
      expect(Doorkeeper.configuration.handle_auth_errors).to eq(:render)
    end
    it "can change the value" do
      Doorkeeper.configure do
        orm DOORKEEPER_ORM
        handle_auth_errors :raise
      end
      expect(subject.handle_auth_errors).to eq(:raise)
    end
  end

  describe "token_secret_strategy" do
    it "is plain by default" do
      expect(subject.token_secret_strategy).to eq(Doorkeeper::SecretStoring::Plain)
      expect(subject.token_secret_fallback_strategy).to eq(nil)
    end

    context "when provided" do
      before do
        Doorkeeper.configure do
          hash_token_secrets
        end
      end

      it "will enable hashing for applications" do
        expect(subject.token_secret_strategy).to eq(Doorkeeper::SecretStoring::Sha256Hash)
        expect(subject.token_secret_fallback_strategy).to eq(nil)
      end
    end

    context "when manually provided with invalid constant" do
      it "raises an exception" do
        expect do
          Doorkeeper.configure do
            hash_token_secrets using: "does not exist"
          end
        end.to raise_error(NameError)
      end
    end

    context "when manually provided with invalid option" do
      it "raises an exception" do
        expect do
          Doorkeeper.configure do
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
          hash_token_secrets fallback: :plain
        end
      end

      it "will enable hashing for applications" do
        expect(subject.token_secret_strategy).to eq(Doorkeeper::SecretStoring::Sha256Hash)
        expect(subject.token_secret_fallback_strategy).to eq(Doorkeeper::SecretStoring::Plain)
      end
    end

    describe "hash_token_secrets together with reuse_access_token" do
      it "will disable reuse_access_token" do
        expect(Rails.logger).to receive(:warn).with(/reuse_access_token will be disabled/)

        Doorkeeper.configure do
          reuse_access_token
          hash_token_secrets
        end

        expect(subject.reuse_access_token).to eq(false)
      end
    end
  end

  describe "application_secret_strategy" do
    it "is plain by default" do
      expect(subject.application_secret_strategy).to eq(Doorkeeper::SecretStoring::Plain)
      expect(subject.application_secret_fallback_strategy).to eq(nil)
    end

    context "when provided" do
      before do
        Doorkeeper.configure do
          hash_application_secrets
        end
      end

      it "will enable hashing for applications" do
        expect(subject.application_secret_strategy).to eq(Doorkeeper::SecretStoring::Sha256Hash)
        expect(subject.application_secret_fallback_strategy).to eq(nil)
      end
    end

    context "when manually provided with invalid constant" do
      it "raises an exception" do
        expect do
          Doorkeeper.configure do
            hash_application_secrets using: "does not exist"
          end
        end.to raise_error(NameError)
      end
    end

    context "when provided with fallback" do
      before do
        Doorkeeper.configure do
          hash_application_secrets fallback: :plain
        end
      end

      it "will enable hashing for applications" do
        expect(subject.application_secret_strategy).to eq(Doorkeeper::SecretStoring::Sha256Hash)
        expect(subject.application_secret_fallback_strategy).to eq(Doorkeeper::SecretStoring::Plain)
      end
    end
  end

  describe "options deprecation" do
    it "prints a warning message when an option is deprecated" do
      expect(Kernel).to receive(:warn).with(
        "[DOORKEEPER] native_redirect_uri has been deprecated and will soon be removed",
      )
      Doorkeeper.configure do
        native_redirect_uri "urn:ietf:wg:oauth:2.0:oob"
      end
    end
  end
end
