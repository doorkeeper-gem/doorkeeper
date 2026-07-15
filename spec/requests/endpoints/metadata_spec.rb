# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Authorization Server Metadata endpoint" do
  before do
    default_scopes_exist :read
    optional_scopes_exist :write, :publish
  end

  it "returns json" do
    get "/.well-known/oauth-authorization-server"

    response_status_should_be(200)

    expect(json_response).to have_key("issuer")
    expect(json_response).to have_key("authorization_endpoint")
    expect(json_response).to have_key("token_endpoint")
    expect(json_response).to have_key("revocation_endpoint")
    expect(json_response).to have_key("introspection_endpoint")
    expect(json_response).to have_key("userinfo_endpoint")
    expect(json_response).to have_key("scopes_supported")
    expect(json_response).to have_key("response_types_supported")
    expect(json_response).to have_key("response_modes_supported")
    expect(json_response).to have_key("grant_types_supported")
    expect(json_response).to have_key("token_endpoint_auth_methods_supported")
    expect(json_response).to have_key("code_challenge_methods_supported")

    expect(json_response["issuer"]).to be_a(String)

    # userinfo_endpoint is intentionally null for backwards compatibility; it is
    # meant to be populated through custom_metadata (e.g. by an OIDC extension).
    expect(json_response["userinfo_endpoint"]).to be_nil

    expect(json_response["scopes_supported"]).to be_a(Array)
    expect(json_response["response_types_supported"]).to be_a(Array)
    expect(json_response["response_modes_supported"]).to be_a(Array)
    expect(json_response["grant_types_supported"]).to be_a(Array)
    expect(json_response["token_endpoint_auth_methods_supported"]).to be_a(Array)
    expect(json_response["code_challenge_methods_supported"]).to be_a(Array)
  end

  context "with custom issuer" do
    before do
      config_is_set(:issuer, "https://example.test")
    end

    it "returns the configured issuer" do
      get "/.well-known/oauth-authorization-server"

      response_status_should_be(200)
      expect(json_response["issuer"]).to eq "https://example.test"
    end

    it "advertises RFC 9207 iss parameter support" do
      get "/.well-known/oauth-authorization-server"

      response_status_should_be(200)
      expect(json_response["authorization_response_iss_parameter_supported"]).to be true
    end
  end

  context "without a custom issuer" do
    it "does not advertise RFC 9207 iss parameter support" do
      get "/.well-known/oauth-authorization-server"

      response_status_should_be(200)
      expect(json_response["authorization_response_iss_parameter_supported"]).to be false
    end
  end

  context "with a blank issuer (e.g. an unset env var)" do
    before do
      config_is_set(:issuer, "")
    end

    it "falls back to the request base URL and does not advertise iss support" do
      get "/.well-known/oauth-authorization-server"

      response_status_should_be(200)
      expect(json_response["issuer"]).to eq "http://www.example.com"
      expect(json_response["authorization_response_iss_parameter_supported"]).to be false
    end
  end

  context "with code challenge methods" do
    before do
      config_is_set(:pkce_code_challenge_methods, ["S256"])
    end

    it "returns the configured code challenge methods" do
      get "/.well-known/oauth-authorization-server"

      response_status_should_be(200)
      expect(json_response["code_challenge_methods_supported"]).to eq(["S256"])
    end
  end

  context "with refresh tokens enabled" do
    before do
      config_is_set(:refresh_token_enabled, true)
    end

    it "includes refresh_token in grant_types_supported" do
      get "/.well-known/oauth-authorization-server"

      response_status_should_be(200)
      expect(json_response["grant_types_supported"]).to include("refresh_token")
    end
  end

  context "with a response-type-only flow enabled (implicit)" do
    before do
      config_is_set(:grant_flows, %w[authorization_code implicit client_credentials])
    end

    it "omits implicit from grant_types_supported (it has no token-endpoint grant type)" do
      get "/.well-known/oauth-authorization-server"

      response_status_should_be(200)
      expect(json_response["grant_types_supported"]).to contain_exactly(
        "authorization_code", "client_credentials"
      )
    end

    it "still advertises implicit in response_types_supported" do
      get "/.well-known/oauth-authorization-server"

      response_status_should_be(200)
      expect(json_response["response_types_supported"]).to include("token")
    end
  end

  context "with token introspection enabled (default)" do
    it "includes the introspection_endpoint" do
      get "/.well-known/oauth-authorization-server"

      response_status_should_be(200)
      expect(json_response).to have_key("introspection_endpoint")
      expect(json_response["introspection_endpoint"]).to be_a(String)
    end
  end

  context "without token introspection" do
    before do
      config_is_set(:allow_token_introspection, false)
    end

    it "omits the introspection_endpoint" do
      get "/.well-known/oauth-authorization-server"

      response_status_should_be(200)
      expect(json_response).not_to have_key("introspection_endpoint")
    end
  end

  context "with controllers disabled through skip_controllers" do
    # skip_controllers leaves no routes mapping for the disabled controllers, so
    # the metadata response does not advertise their endpoints. Emulate that by
    # deleting the mapping entries rather than re-drawing the routes: across the
    # Rails versions exercised in CI, `draw` does not reliably clear the routes
    # installed at boot, so url generation for the "disabled" controllers can
    # still succeed and the skip goes undetected.
    before do
      @original_mapping = Doorkeeper::Rails::Routes.mapping.dup
      Doorkeeper::Rails::Routes.mapping.delete(:authorizations)
      Doorkeeper::Rails::Routes.mapping.delete(:tokens)
    end

    after do
      Doorkeeper::Rails::Routes.mapping.replace(@original_mapping)
    end

    it "responds successfully and omits the disabled endpoints" do
      get "/.well-known/oauth-authorization-server"

      response_status_should_be(200)

      # The disabled controllers have no routes mapping, so their endpoints
      # must not be advertised in the metadata.
      expect(json_response).not_to have_key("authorization_endpoint")
      expect(json_response).not_to have_key("token_endpoint")
      expect(json_response).not_to have_key("revocation_endpoint")
      expect(json_response).not_to have_key("introspection_endpoint")

      # Endpoint-independent metadata is still present.
      expect(json_response).to have_key("issuer")
      expect(json_response).to have_key("scopes_supported")
    end
  end

  context "with a custom tokens controller outside the doorkeeper namespace" do
    # Regression: endpoint_for passed the configured controller name to url_for
    # unanchored, so Rails resolved it relative to the current
    # (doorkeeper/metadata) namespace whenever their segment depths differed —
    # `controllers tokens: "custom_tokens"` was looked up as
    # "doorkeeper/custom_tokens" and raised ActionController::UrlGenerationError.
    #
    # The routes must be redrawn per example (not in before(:all)): route
    # drawing consults Doorkeeper.config (e.g. allow_token_introspection gates
    # the introspect route), and before(:all) runs before the global config
    # reset hook, so it would draw against whatever config the previous example
    # happened to leave behind.
    before do
      @original_disable_clear_and_finalize = Rails.application.routes.disable_clear_and_finalize
      Rails.application.routes.disable_clear_and_finalize = false
      Rails.application.routes.draw do
        use_doorkeeper do
          controllers tokens: "custom_tokens"
        end
      end
    end

    # The flag must be restored only after the dummy routes are reloaded: if
    # the captured value is true, restoring it first would make the reload
    # skip clear!/finalize! and leave the routes unusable for later specs.
    after do
      Rails.application.routes.clear!

      load File.expand_path("../../dummy/config/routes.rb", __dir__)

      Rails.application.routes.disable_clear_and_finalize = @original_disable_clear_and_finalize
    end

    it "advertises the custom controller's endpoints" do
      get "/.well-known/oauth-authorization-server"

      response_status_should_be(200)

      expect(json_response["authorization_endpoint"]).to eq("http://www.example.com/oauth/authorize")
      expect(json_response["token_endpoint"]).to eq("http://www.example.com/oauth/token")
      expect(json_response["revocation_endpoint"]).to eq("http://www.example.com/oauth/revoke")
      expect(json_response["introspection_endpoint"]).to eq("http://www.example.com/oauth/introspect")
    end
  end

  context "with custom metadata attributes" do
    before do
      config_is_set(
        :custom_metadata,
        userinfo_endpoint: "/userinfo",
        app_registration_url: "app_registration_url.example",
      )
    end

    it "merges the custom metadata into the response" do
      get "/.well-known/oauth-authorization-server"

      response_status_should_be(200)
      expect(json_response["userinfo_endpoint"]).to eq("/userinfo")
      expect(json_response["app_registration_url"]).to eq("app_registration_url.example")
    end
  end

  context "with explicit client_authentication configuration" do
    before do
      config_is_set(:client_authentication, %i[client_secret_basic])
    end

    it "returns only the configured authentication methods" do
      get "/.well-known/oauth-authorization-server"

      response_status_should_be(200)
      expect(json_response["token_endpoint_auth_methods_supported"]).to eq(%w[client_secret_basic])
    end
  end

  context "with an unregistered client_authentication method configured" do
    before do
      config_is_set(:client_authentication, %i[client_secret_basic private_key_jwt])
    end

    it "does not advertise the method the resolver ignores" do
      get "/.well-known/oauth-authorization-server"

      response_status_should_be(200)
      expect(json_response["token_endpoint_auth_methods_supported"]).to eq(%w[client_secret_basic])
    end
  end

  context "with a duplicated client_authentication method configured" do
    before do
      config_is_set(:client_authentication, %i[client_secret_basic client_secret_post client_secret_basic])
    end

    it "advertises each method once" do
      get "/.well-known/oauth-authorization-server"

      response_status_should_be(200)
      expect(json_response["token_endpoint_auth_methods_supported"])
        .to eq(%w[client_secret_basic client_secret_post])
    end
  end

  context "with a custom client_authentication method registered by an extension" do
    before do
      Doorkeeper::ClientAuthentication.register(
        :private_key_jwt,
        double(matches_request?: false, authenticate: nil),
      )
      config_is_set(:client_authentication, %i[client_secret_basic private_key_jwt])
    end

    after do
      # The example only adds this one method, so removing it restores the
      # registry in-place without replacing the Hash other code may hold.
      Doorkeeper::ClientAuthentication::Registry.registered_methods.delete(:private_key_jwt)
    end

    it "advertises the custom method alongside the built-ins" do
      get "/.well-known/oauth-authorization-server"

      response_status_should_be(200)
      expect(json_response["token_endpoint_auth_methods_supported"])
        .to eq(%w[client_secret_basic private_key_jwt])
    end
  end

  context "with a deprecated client_credentials-only configuration" do
    before do
      # The legacy DSL converts client_credentials names and stores them in
      # @client_credentials_methods (see Config::Builder#client_credentials);
      # derive the stored value through the real conversion so this example
      # stays coupled to what `client_credentials :from_basic` actually stores.
      config_is_set(
        :client_credentials_methods,
        Doorkeeper::ClientAuthentication.from_legacy_client_credentials(%i[from_basic]),
      )
    end

    it "advertises the legacy-derived methods instead of the defaults" do
      get "/.well-known/oauth-authorization-server"

      response_status_should_be(200)
      expect(json_response["token_endpoint_auth_methods_supported"]).to eq(%w[client_secret_basic])
    end
  end
end
