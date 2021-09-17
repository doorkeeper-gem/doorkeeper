# frozen_string_literal: true

require "spec_helper"

feature "Implicit Grant Flow Errors" do
  background do
    default_scopes_exist :default
    config_is_set(:authenticate_resource_owner) { User.first || redirect_to("/sign_in") }
    config_is_set(:grant_flows, ["implicit"])
    client_exists
    create_resource_owner
    sign_in
  end

  after do
    access_token_should_not_exist
  end

  context "when validate client_id param" do
    scenario "displays invalid_client error for invalid client_id" do
      visit authorization_endpoint_url(client_id: "invalid", response_type: "token")
      i_should_not_see "Authorize"
      i_should_see_translated_error_message :invalid_client
    end

    scenario "displays invalid_request error when client_id is missing" do
      visit authorization_endpoint_url(client_id: "", response_type: "token")
      i_should_not_see "Authorize"
      i_should_see_translated_invalid_request_error_message :missing_param, :client_id
    end
  end

  context "when validate redirect_uri param" do
    scenario "displays invalid_redirect_uri error for invalid redirect_uri" do
      visit authorization_endpoint_url(client: @client, redirect_uri: "invalid", response_type: "token")
      i_should_not_see "Authorize"
      i_should_see_translated_error_message :invalid_redirect_uri
    end

    scenario "displays invalid_redirect_uri error when redirect_uri is missing" do
      visit authorization_endpoint_url(client: @client, redirect_uri: "", response_type: "token")
      i_should_not_see "Authorize"
      i_should_see_translated_error_message :invalid_redirect_uri
    end
  end

  context "when validate response_mode param" do
    scenario "displays unsupported_response_mode error when using 'query' response mode" do
      visit authorization_endpoint_url(client: @client, response_type: "token", response_mode: "query")
      i_should_not_see "Authorize"
      i_should_see_translated_error_message :unsupported_response_mode
    end
  end
end
