# frozen_string_literal: true

require "spec_helper"

feature "Implicit Grant Flow (feature spec)" do
  background do
    default_scopes_exist :default
    config_is_set(:authenticate_resource_owner) { User.first || redirect_to("/sign_in") }
    config_is_set(:grant_flows, ["implicit"])
    client_exists
    create_resource_owner
    sign_in
  end

  scenario "resource owner authorizes the client" do
    visit authorization_endpoint_url(client: @client, response_type: "token")
    click_on "Authorize"

    access_token_should_exist_for @client, @resource_owner

    i_should_be_on_client_callback @client
  end

  context "when application scopes are present and no scope is passed" do
    background do
      @client.update(scopes: "public write read")
    end

    scenario "scope is invalid because default scope is different from application scope" do
      default_scopes_exist :admin
      visit authorization_endpoint_url(client: @client, response_type: "token")
      response_status_should_be 200
      i_should_not_see "Authorize"
      i_should_see_translated_error_message :invalid_scope
    end

    scenario "access token has scopes which are common in application scopes and default scopes" do
      default_scopes_exist :public, :write
      visit authorization_endpoint_url(client: @client, response_type: "token")
      click_on "Authorize"
      access_token_should_exist_for @client, @resource_owner
      access_token_should_have_scopes :public, :write
    end
  end

  context "when configured so that redirect uri is optional during authorization" do
    before do
      config_is_set(:redirect_uri_optional_during_authorization, true)
    end

    scenario "resource owner authorizes the client without the redirect uri provided" do
      visit authorization_endpoint_url(client: @client, redirect_uri: "", response_type: "token")
      click_on "Authorize"
      access_token_should_exist_for @client, @resource_owner
      i_should_be_on_client_callback @client
    end
  end
end

RSpec.describe "Implicit Grant Flow (request spec)" do
  before do
    default_scopes_exist :default
    config_is_set(:authenticate_resource_owner) { User.first || redirect_to("/sign_in") }
    config_is_set(:grant_flows, ["implicit"])
    client_exists
    create_resource_owner
  end

  context "when reuse_access_token enabled" do
    it "returns a new token each request" do
      allow(Doorkeeper.configuration).to receive(:reuse_access_token).and_return(false)

      token = client_is_authorized(@client, @resource_owner, scopes: "default")

      post "/oauth/authorize",
           params: {
             client_id: @client.uid,
             state: "",
             redirect_uri: @client.redirect_uri,
             response_type: "token",
             commit: "Authorize",
           }

      expect(response.location).not_to include(token.token)
    end

    it "returns the same token if it is still accessible" do
      allow(Doorkeeper.configuration).to receive(:reuse_access_token).and_return(true)

      token = client_is_authorized(@client, @resource_owner, scopes: "default")

      post "/oauth/authorize",
           params: {
             client_id: @client.uid,
             state: "",
             redirect_uri: @client.redirect_uri,
             response_type: "token",
             commit: "Authorize",
           }

      expect(response.location).to include(token.token)
    end
  end
end
