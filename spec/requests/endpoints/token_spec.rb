# frozen_string_literal: true

require "spec_helper"

describe "Token endpoint" do
  before do
    client_exists
  end

  context "#authorization code" do
    before do
      authorization_code_exists application: @client, scopes: "public"
    end

    it "respond with correct headers" do
      post token_endpoint_url(code: @authorization.token, client: @client)
      should_have_header "Pragma", "no-cache"

      # Rails 5.2 changed headers
      if ::Rails::VERSION::MAJOR >= 5 && ::Rails::VERSION::MINOR >= 2 || ::Rails::VERSION::MAJOR >= 6
        should_have_header "Cache-Control", "private, no-store"
      else
        should_have_header "Cache-Control", "no-store"
      end

      should_have_header "Content-Type", "application/json; charset=utf-8"
    end

    it "accepts client credentials with basic auth header" do
      post token_endpoint_url,
           params: {
             code: @authorization.token,
             redirect_uri: @client.redirect_uri,
           },
           headers: { "HTTP_AUTHORIZATION" => basic_auth_header_for_client(@client) }

      should_have_json "access_token", Doorkeeper::AccessToken.first.token
    end

    it "returns null for expires_in when a permanent token is set" do
      config_is_set(:access_token_expires_in, nil)
      post token_endpoint_url(code: @authorization.token, client: @client)
      should_have_json "access_token", Doorkeeper::AccessToken.first.token
      should_not_have_json "expires_in"
    end

    it "returns unsupported_grant_type for invalid grant_type param" do
      post token_endpoint_url(code: @authorization.token, client: @client, grant_type: "nothing")

      should_not_have_json "access_token"
      should_have_json "error", "unsupported_grant_type"
      should_have_json "error_description", translated_error_message("unsupported_grant_type")
    end

    it "returns unsupported_grant_type for disabled grant flows" do
      config_is_set(:grant_flows, ["implicit"])
      post token_endpoint_url(code: @authorization.token, client: @client, grant_type: "authorization_code")

      should_not_have_json "access_token"
      should_have_json "error", "unsupported_grant_type"
      should_have_json "error_description", translated_error_message("unsupported_grant_type")
    end

    it "returns unsupported_grant_type when refresh_token is not in use" do
      post token_endpoint_url(code: @authorization.token, client: @client, grant_type: "refresh_token")

      should_not_have_json "access_token"
      should_have_json "error", "unsupported_grant_type"
      should_have_json "error_description", translated_error_message("unsupported_grant_type")
    end

    it "returns invalid_request if grant_type is missing" do
      post token_endpoint_url(code: @authorization.token, client: @client, grant_type: "")

      should_not_have_json "access_token"
      should_have_json "error", "invalid_request"
      should_have_json "error_description", translated_error_message("invalid_request")
    end
  end

  unless ENV["WITHOUT_DEVICE_CODE"]
    context "#device_code polling" do
      before do
        device_code_exists application_id: @client.id
      end

      it "respond with correct headers" do
        config_is_set(:grant_flows, ["urn:ietf:params:oauth:grant-type:device_code"])
        post token_endpoint_url(client: @client, device_code: @access_grant.token, redirect_uri: nil, grant_type: "urn:ietf:params:oauth:grant-type:device_code")
        should_have_header "Content-Type", "application/json; charset=utf-8"
      end

      it "responds with access_token after user has accepted the grant" do
        config_is_set(:grant_flows, ["urn:ietf:params:oauth:grant-type:device_code"])
        @access_grant.update! user_code: nil, resource_owner_id: create_resource_owner.id
        post token_endpoint_url(client: @client, device_code: @access_grant.token, redirect_uri: nil, grant_type: "urn:ietf:params:oauth:grant-type:device_code")

        should_have_json "access_token", Doorkeeper::AccessToken.last.token
        should_have_json "expires_in", 7200
      end

      it "responds with to fast, if polling requests in less then 4 seconds" do
        config_is_set(:grant_flows, ["urn:ietf:params:oauth:grant-type:device_code"])
        @access_grant.update! last_polling_at: Time.now
        post token_endpoint_url(client: @client, device_code: @access_grant.token, redirect_uri: nil, grant_type: "urn:ietf:params:oauth:grant-type:device_code")

        should_not_have_json "access_token"
        should_have_json "error", "slow_down"
        should_have_json "error_description", translated_error_message("slow_down")
      end

      it "responds with authorization pending, if user has not authorized yet" do
        config_is_set(:grant_flows, ["urn:ietf:params:oauth:grant-type:device_code"])
        post token_endpoint_url(client: @client, device_code: @access_grant.token, redirect_uri: nil, grant_type: "urn:ietf:params:oauth:grant-type:device_code")

        should_not_have_json "access_token"
        should_have_json "error", "authorization_pending"
        should_have_json "error_description", translated_error_message("authorization_pending")
      end

      it "responds with invalid grant, if grant was revoked" do
        config_is_set(:grant_flows, ["urn:ietf:params:oauth:grant-type:device_code"])
        @access_grant.update! revoked_at: Time.now
        post token_endpoint_url(client: @client, device_code: @access_grant.token, redirect_uri: nil, grant_type: "urn:ietf:params:oauth:grant-type:device_code")

        should_not_have_json "invalid_grant"
        should_have_json "error", "access_denied"
        should_have_json "error_description", translated_error_message("access_denied")
      end

      it "responds with invalid grant, if grant is expired" do
        config_is_set(:grant_flows, ["urn:ietf:params:oauth:grant-type:device_code"])
        @access_grant.update! expires_in: -100
        post token_endpoint_url(client: @client, device_code: @access_grant.token, redirect_uri: nil, grant_type: "urn:ietf:params:oauth:grant-type:device_code")

        should_not_have_json "invalid_grant"
        should_have_json "error", "invalid_grant"
        should_have_json "error_description", translated_error_message("invalid_grant")
      end
    end
  end
end
