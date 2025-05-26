# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Token endpoint" do
  before do
    client_exists
    create_resource_owner
    authorization_code_exists application: @client,
                              scopes: "public",
                              resource_owner_id: @resource_owner.id,
                              resource_owner_type: @resource_owner.class.name
  end

  it "respond with correct headers" do
    post token_endpoint_url, params: token_endpoint_params(code: @authorization.token, client: @client)

    expect(headers["Cache-Control"]).to be_in(["no-store", "no-cache, no-store", "private, no-store"])
    expect(headers["Content-Type"]).to eq("application/json; charset=utf-8")
    expect(headers["Pragma"]).to eq("no-cache")
  end

  it "accepts client credentials with basic auth header" do
    post token_endpoint_url,
         params: token_endpoint_params(
           code: @authorization.token,
           redirect_uri: @client.redirect_uri,
         ),
         headers: { "HTTP_AUTHORIZATION" => basic_auth_header_for_client(@client) }

    expect(json_response).to include("access_token" => Doorkeeper::AccessToken.first.token)
  end

  it "returns null for expires_in when a permanent token is set" do
    config_is_set(:access_token_expires_in, nil)

    post token_endpoint_url, params: token_endpoint_params(code: @authorization.token, client: @client)

    expect(json_response).to include("access_token" => Doorkeeper::AccessToken.first.token)
    expect(json_response).not_to include("expires_in")
  end

  it "returns unsupported_grant_type for invalid grant_type param" do
    post token_endpoint_url, params: token_endpoint_params(code: @authorization.token, client: @client, grant_type: "nothing")

    expect(json_response).to match(
      "error" => "unsupported_grant_type",
      "error_description" => translated_error_message("unsupported_grant_type"),
    )
  end

  it "returns unsupported_grant_type for disabled grant flows" do
    config_is_set(:grant_flows, ["implicit"])
    post token_endpoint_url, params: token_endpoint_params(code: @authorization.token, client: @client, grant_type: "authorization_code")

    expect(json_response).to match(
      "error" => "unsupported_grant_type",
      "error_description" => translated_error_message("unsupported_grant_type"),
    )
  end

  it "returns unsupported_grant_type when refresh_token is not in use" do
    post token_endpoint_url, params: token_endpoint_params(code: @authorization.token, client: @client, grant_type: "refresh_token")

    expect(json_response).to match(
      "error" => "unsupported_grant_type",
      "error_description" => translated_error_message("unsupported_grant_type"),
    )
  end

  it "returns invalid_request if grant_type is missing" do
    post token_endpoint_url, params: token_endpoint_params(code: @authorization.token, client: @client, grant_type: "")

    expect(json_response).to match(
      "error" => "invalid_request",
      "error_description" => translated_invalid_request_error_message(:missing_param, :grant_type),
    )
  end
end
