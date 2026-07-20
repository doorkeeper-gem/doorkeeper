# frozen_string_literal: true

require "spec_helper"

feature "Authorization Code Flow Errors" do
  let(:client_params) { {} }

  background do
    default_scopes_exist :default
    config_is_set(:authenticate_resource_owner) { User.first || redirect_to("/sign_in") }
    client_exists client_params
    create_resource_owner
    sign_in
  end

  after do
    access_grant_should_not_exist
  end

  context "with a client trying to xss resource owner" do
    let(:client_name) { "<div id='xss'>XSS</div>" }
    let(:client_params) { { name: client_name } }

    scenario "resource owner visit authorization endpoint" do
      visit authorization_endpoint_url(client: @client)
      expect(page).not_to have_css("#xss")
    end
  end

  context "when access was denied" do
    scenario "redirects with error" do
      visit authorization_endpoint_url(client: @client)
      click_on "Deny"

      i_should_be_on_client_callback @client
      url_should_not_have_param "code"
      url_should_have_param "error", "access_denied"
      url_should_have_param "error_description", translated_error_message(:access_denied)
    end

    scenario "redirects with state parameter" do
      visit authorization_endpoint_url(client: @client, state: "return-this")
      click_on "Deny"

      i_should_be_on_client_callback @client
      url_should_not_have_param "code"
      url_should_have_param "state", "return-this"
    end

    # RFC 9207: an authorization error response redirected back to the client
    # must carry the issuer when one is configured.
    scenario "redirects with iss when an issuer is configured" do
      config_is_set(:issuer, "https://auth.example.com")

      visit authorization_endpoint_url(client: @client)
      click_on "Deny"

      i_should_be_on_client_callback @client
      url_should_have_param "error", "access_denied"
      url_should_have_param "iss", "https://auth.example.com"
    end

    scenario "redirects without iss when no issuer is configured" do
      visit authorization_endpoint_url(client: @client)
      click_on "Deny"

      i_should_be_on_client_callback @client
      url_should_have_param "error", "access_denied"
      url_should_not_have_param "iss"
    end
  end
end

RSpec.describe "Authorization Code Flow Errors after authorization" do
  before do
    client_exists
    create_resource_owner
    authorization_code_exists application: @client,
                              resource_owner_id: @resource_owner.id,
                              resource_owner_type: @resource_owner.class.name
  end

  it "returns :invalid_grant error when posting an already revoked grant code" do
    # First successful request
    post token_endpoint_url, params: token_endpoint_params(code: @authorization.token, client: @client)

    # Second attempt with same token
    expect do
      post token_endpoint_url, params: token_endpoint_params(code: @authorization.token, client: @client)
    end.not_to(change { Doorkeeper::AccessToken.count })

    expect(json_response).to match(
      "error" => "invalid_grant",
      "error_description" => translated_error_message("invalid_grant"),
    )
  end

  it "revokes the token issued for the code when it is exchanged twice (RFC 6749 §4.1.2)" do
    post token_endpoint_url, params: token_endpoint_params(code: @authorization.token, client: @client)

    issued_token = Doorkeeper::AccessToken.by_token(json_response["access_token"])

    post token_endpoint_url, params: token_endpoint_params(code: @authorization.token, client: @client)

    expect(json_response).to include("error" => "invalid_grant")
    expect(issued_token.reload).to be_revoked
  end

  it "returns :invalid_grant error for invalid grant code" do
    post token_endpoint_url, params: token_endpoint_params(code: "invalid", client: @client)

    access_token_should_not_exist

    expect(json_response).to match(
      "error" => "invalid_grant",
      "error_description" => translated_error_message("invalid_grant"),
    )
  end

  # RFC 9207 scopes the iss parameter to authorization responses. Token
  # endpoint errors share ErrorResponse but must not leak iss even when an
  # issuer is configured.
  it "omits iss from token endpoint errors even when an issuer is configured" do
    config_is_set(:issuer, "https://auth.example.com")

    post token_endpoint_url, params: token_endpoint_params(code: "invalid", client: @client)

    expect(json_response).not_to have_key("iss")
  end
end
