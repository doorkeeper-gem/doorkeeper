# frozen_string_literal: true

require "spec_helper"
require "openssl"
require "jwt"

RSpec.describe "JWT Bearer (ID-JAG) grant" do
  let(:rsa) { OpenSSL::PKey::RSA.generate(2048) }
  let(:issuer) { "https://idp.example.com" }
  let(:audience) { "https://rs.example.com" }

  def make_assertion(key, subject:, client_id:, alg: "RS256", payload: {})
    now = Time.now.to_i
    claims = {
      "iss" => issuer, "sub" => subject, "aud" => audience, "client_id" => client_id,
      "jti" => SecureRandom.hex(8), "exp" => now + 300, "iat" => now,
    }.merge(payload)
    JWT.encode(claims, key, alg, { typ: "oauth-id-jag+jwt" })
  end

  before do
    client_exists(confidential: true)
    create_resource_owner

    config_is_set(:grant_flows, %w[jwt_bearer])
    config_is_set(:jwt_bearer_audience, audience)
    config_is_set(:jwt_bearer_trusted_issuer, ->(iss) { iss == issuer })
    config_is_set(:jwt_bearer_issuer_key, ->(_iss, _kid) { rsa.public_key })
    config_is_set(:jwt_bearer_resource_owner_from_assertion, ->(_iss, _sub, _client) { @resource_owner })
  end

  it "issues an access token for a valid assertion, with a confidential client" do
    assertion = make_assertion(rsa, subject: @resource_owner.name, client_id: @client.uid)

    post "/oauth/token",
         params: { grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer", assertion: assertion },
         headers: { "HTTP_AUTHORIZATION" => basic_auth_header_for_client(@client) }

    expect(response).to have_http_status(:ok)
    expect(json_response).to include("access_token")
    expect(json_response).not_to include("refresh_token")
    expect(Doorkeeper::AccessToken.first.application_id).to eq(@client.id)
  end

  it "rejects a public client by default" do
    client_exists(confidential: false)
    assertion = make_assertion(rsa, subject: @resource_owner.name, client_id: @client.uid)

    post "/oauth/token",
         params: { grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer", assertion: assertion },
         headers: { "HTTP_AUTHORIZATION" => basic_auth_header_for_client(@client) }

    expect(json_response).to include("error" => "unauthorized_client")
  end

  it "rejects a replayed assertion when a replay store is configured" do
    store = Object.new
    def store.consume(jti, _iss, _exp)
      @seen ||= {}
      return false if @seen[jti]

      @seen[jti] = true
      true
    end
    config_is_set(:jwt_bearer_replay_store, store)

    assertion = make_assertion(rsa, subject: @resource_owner.name, client_id: @client.uid)

    post "/oauth/token",
         params: { grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer", assertion: assertion },
         headers: { "HTTP_AUTHORIZATION" => basic_auth_header_for_client(@client) }
    expect(response).to have_http_status(:ok)

    post "/oauth/token",
         params: { grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer", assertion: assertion },
         headers: { "HTTP_AUTHORIZATION" => basic_auth_header_for_client(@client) }
    expect(json_response).to include("error" => "invalid_grant")
  end

  it "rejects a tampered signature" do
    assertion = make_assertion(rsa, subject: @resource_owner.name, client_id: @client.uid)
    tampered = "#{assertion[0..-2]}#{assertion[-1] == "A" ? "B" : "A"}"

    post "/oauth/token",
         params: { grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer", assertion: tampered },
         headers: { "HTTP_AUTHORIZATION" => basic_auth_header_for_client(@client) }

    expect(json_response).to include("error" => "invalid_grant")
  end

  it "narrows scope to the intersection of requested and assertion scope" do
    config_is_set(:default_scopes, Doorkeeper::OAuth::Scopes.from_string("read write"))
    assertion = make_assertion(rsa, subject: @resource_owner.name, client_id: @client.uid, payload: { "scope" => "read write" })

    post "/oauth/token",
         params: { grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer", assertion: assertion, scope: "read" },
         headers: { "HTTP_AUTHORIZATION" => basic_auth_header_for_client(@client) }

    expect(response).to have_http_status(:ok)
    expect(Doorkeeper::AccessToken.first.scopes).to eq(Doorkeeper::OAuth::Scopes.from_array(["read"]))
  end

  it "rejects a request missing the assertion parameter" do
    post "/oauth/token",
         params: { grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer" },
         headers: { "HTTP_AUTHORIZATION" => basic_auth_header_for_client(@client) }

    expect(json_response).to include("error" => "invalid_request")
  end

  it "rejects an assertion from an untrusted issuer" do
    assertion = make_assertion(rsa, subject: @resource_owner.name, client_id: @client.uid, payload: { "iss" => "https://evil.example.com" })

    post "/oauth/token",
         params: { grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer", assertion: assertion },
         headers: { "HTTP_AUTHORIZATION" => basic_auth_header_for_client(@client) }

    expect(json_response).to include("error" => "invalid_grant")
  end

  it "rejects a request with the wrong client_secret, even with an otherwise-valid assertion" do
    assertion = make_assertion(rsa, subject: @resource_owner.name, client_id: @client.uid)

    post "/oauth/token",
         params: {
           grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
           assertion: assertion,
           client_id: @client.uid,
           client_secret: "wrong-secret",
         }

    expect(response).to have_http_status(:unauthorized)
    expect(json_response).to include("error" => "invalid_client")
    expect(Doorkeeper::AccessToken.count).to be_zero
  end

  it "returns unsupported_grant_type when the jwt_bearer flow is not enabled" do
    config_is_set(:grant_flows, %w[client_credentials])
    assertion = make_assertion(rsa, subject: @resource_owner.name, client_id: @client.uid)

    post "/oauth/token",
         params: { grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer", assertion: assertion },
         headers: { "HTTP_AUTHORIZATION" => basic_auth_header_for_client(@client) }

    expect(json_response).to include("error" => "unsupported_grant_type")
  end
end
