# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Discovery endpoint" do
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
    expect(json_response).to have_key("userinfo_endpoint")
    expect(json_response).to have_key("scopes_supported")
    expect(json_response).to have_key("response_types_supported")
    expect(json_response).to have_key("response_modes_supported")
    expect(json_response).to have_key("grant_types_supported")
    expect(json_response).to have_key("token_endpoint_auth_methods_supported")
    expect(json_response).to have_key("code_challenge_methods_supported")

    expect(json_response["issuer"]).to be_a(String)

    expect(json_response["scopes_supported"]).to be_a(Array)
    expect(json_response["response_types_supported"]).to be_a(Array)
    expect(json_response["response_modes_supported"]).to be_a(Array)
    expect(json_response["grant_types_supported"]).to be_a(Array)
    expect(json_response["token_endpoint_auth_methods_supported"]).to be_a(Array)
    expect(json_response["code_challenge_methods_supported"]).to be_a(Array)
  end

  context 'With custom issuer' do
    before do
      config_is_set(:issuer, "http://example.test/")
    end

    it "returns json" do
      get "/.well-known/oauth-authorization-server"
      
      response_status_should_be(200)
      expect(json_response["issuer"]).to eq "http://example.test/"
    end
  end

  context 'With code challenge methods' do
    before do
      config_is_set(:pkce_code_challenge_methods, ["S256"])
    end

    it "returns json" do
      get "/.well-known/oauth-authorization-server"
      
      response_status_should_be(200)
      expect(json_response["code_challenge_methods_supported"]).to eq(["S256"])
    end
  end

  context 'With custom discovery attributes' do
    before do
      config_is_set(:custom_discovery_data, {
        userinfo_endpoint: '/userinfo',
        app_registration_url: 'app_registration_url.example'
      })
    end

    it "returns json" do
      get "/.well-known/oauth-authorization-server"

      response_status_should_be(200)
      expect(json_response["userinfo_endpoint"]).to eq("/userinfo")
      expect(json_response["app_registration_url"]).to eq("app_registration_url.example")
    end
  end
end
