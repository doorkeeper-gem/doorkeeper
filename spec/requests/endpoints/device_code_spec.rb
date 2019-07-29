# frozen_string_literal: true

require "spec_helper"

describe "Device Code endpoint" do
  before do
    config_is_set(:grant_flows, ["urn:ietf:params:oauth:grant-type:device_code"])
    client_exists
  end

  unless ENV["WITHOUT_DEVICE_CODE"]
    context "#requests device_code" do
      it "respond with correct headers" do
        post device_code_endpoint_url(client: @client)
        should_have_header "Content-Type", "application/json; charset=utf-8"
      end

      it "accepts client credentials as params" do
        post device_code_endpoint_url(client: @client)

        should_have_json "device_code", Doorkeeper::AccessGrant.first.token
        should_have_json "user_code", Doorkeeper::AccessGrant.first.user_code
        should_have_json "verification_uri", "http://www.example.com/oauth/device"
        should_have_json "verification_uri_complete", "http://www.example.com/oauth/device/#{Doorkeeper::AccessGrant.first&.user_code}"
        should_have_json "expires_in", 300
        should_have_json "interval", 5

        expect(Doorkeeper::AccessGrant.first&.user_code).to match(/\A[A-Z]{4}-[A-Z]{4}\Z/)
      end

      it "allows configuration for user code format" do
        config_is_set(:user_code_format, "6d")
        post device_code_endpoint_url(client: @client)
        expect(Doorkeeper::AccessGrant.first&.user_code).to match(/\A\d{6}\Z/)
      end

      it "accepts client credentials with basic auth header" do
        post device_code_endpoint_url,
             headers: { "HTTP_AUTHORIZATION" => basic_auth_header_for_client(@client) }

        should_have_json "device_code", Doorkeeper::AccessGrant.first.token
        should_have_json "user_code", Doorkeeper::AccessGrant.first.user_code
        should_have_json "verification_uri", "http://www.example.com/oauth/device"
        should_have_json "verification_uri_complete", "http://www.example.com/oauth/device/#{Doorkeeper::AccessGrant.first&.user_code}"
        should_have_json "expires_in", 300
        should_have_json "interval", 5

        expect(Doorkeeper::AccessGrant.first&.user_code).to match(/\A[A-Z]{4}-[A-Z]{4}\Z/)
      end

      it "responds with client required, if no client is given" do
        post device_code_endpoint_url

        should_have_json "error", "invalid_client"
        should_have_json "error_description", translated_error_message("invalid_client")
      end

      it "responds with client required, if client does not exist" do
        post device_code_endpoint_url client_id: "not-existing"

        should_have_json "error", "invalid_client"
        should_have_json "error_description", translated_error_message("invalid_client")
      end
    end
  end
end
