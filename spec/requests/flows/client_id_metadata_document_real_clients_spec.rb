# frozen_string_literal: true

require "spec_helper"
require "jwt"

# The metadata documents of clients that use this flow in production, copied verbatim (2026-11-11)
# into spec/fixtures/cimd/documents.json.
# Whatever changes in the implementation, these have to keep working end to end.
feature "Client ID Metadata Documents of real clients" do
  let(:documents) { json_fixture("cimd/documents.json").transform_keys(&:to_sym) }
  let(:code_verifier) { "a" * 43 }
  let(:rsa_key) { OpenSSL::PKey::RSA.generate(2048) }
  let(:none) { ->(client_id) { { client_id: client_id } } }
  let(:private_key_jwt) do
    lambda do |client_id|
      { client_assertion_type: Doorkeeper::OAuth::ClientAuthentication::PrivateKeyJwt::CLIENT_ASSERTION_TYPE,
        client_assertion: JWT.encode({ iss: client_id, sub: client_id, aud: "http://www.example.com/oauth/token",
                                       exp: 1.minute.from_now.to_i, jti: SecureRandom.hex(8), }, rsa_key, "RS256", { kid: "k" }), }
    end
  end

  background do
    Doorkeeper.configure do
      orm DOORKEEPER_ORM
      use_client_id_metadata_documents
    end
    config_is_set(:refresh_token_enabled, true)
    config_is_set(:issuer, "http://www.example.com")
    # As a host serving native clients sets it: https, except for an RFC 8252 loopback listener.
    config_is_set(:force_ssl_in_redirect_uri, ->(uri) { !Doorkeeper::OAuth::Helpers::URIChecker.loopback_uri?(uri) })
    default_scopes_exist :public
    config_is_set(:authenticate_resource_owner) { User.first || redirect_to("/sign_in") }
    create_resource_owner
    sign_in
    Doorkeeper::OAuth::ClientIdMetadataDocument.cache.clear
    Doorkeeper::OAuth::ClientAuthentication::PrivateKeyJwt::KeyResolver.jwks_cache.clear
    allow(Resolv).to receive(:getaddresses).and_return(["93.184.216.34"])
    documents.each_value { |document| stub_request(:get, document.fetch("client_id")).to_return(status: 200, body: document.to_json) }
    stub_request(:get, "https://chatgpt.com/oauth/jwks.json")
      .to_return(status: 200, headers: { "Content-Type" => "application/json" },
                 body: { keys: [JWT::JWK.new(rsa_key.public_key, { kid: "k" }).export] }.to_json,)
  end

  # Consents and returns the authorization response's parameters. The redirect is not followed, as it
  # leaves for the client's host, which the dummy app does not serve.
  def authorization_response(client_id, redirect_uri)
    allow(page.driver).to receive(:follow_redirects?).and_call_original
    visit authorization_endpoint_url(client_id: client_id, redirect_uri: redirect_uri, state: "s",
                                     code_challenge: Base64.urlsafe_encode64(Digest::SHA256.digest(code_verifier), padding: false),
                                     code_challenge_method: "S256",)
    allow(page.driver).to receive(:follow_redirects?).and_return(false)
    click_on "Authorize"
    Rack::Utils.parse_query(URI.parse(page.response_headers.fetch("Location")).query)
  end

  def token_request(params)
    page.driver.post token_endpoint_url, params
    JSON.parse(page.body)
  end

  # Authorizes, exchanges the code and refreshes, authenticating as +auth+ returns; returns the refresh's response.
  def run_flow(name, redirect_uri, auth)
    client_id = documents.fetch(name).fetch("client_id")
    callback = authorization_response(client_id, redirect_uri)
    expect(callback).to include("state" => "s", "iss" => "http://www.example.com")

    tokens = token_request({ grant_type: "authorization_code", code: callback.fetch("code"), redirect_uri: redirect_uri,
                             code_verifier: code_verifier, }.merge(auth.call(client_id)))
    expect(tokens).to include("access_token", "refresh_token")

    token_request({ grant_type: "refresh_token", refresh_token: tokens.fetch("refresh_token") }.merge(auth.call(client_id)))
  end

  scenario "Claude Code, on a random localhost or loopback IP port" do
    expect(run_flow(:claude_code, "http://localhost:53682/callback", none)).to include("access_token")
    expect(run_flow(:claude_code, "http://127.0.0.1:53683/callback", none)).to include("access_token")
  end

  scenario "Claude (claude.ai)" do
    expect(run_flow(:claude_ai, "https://claude.ai/api/mcp/auth_callback", none)).to include("access_token")
  end

  scenario "Codex, on a random loopback port" do
    expect(run_flow(:codex, "http://127.0.0.1:1455/callback", none)).to include("access_token")
  end

  scenario "ChatGPT, on a server without private_key_jwt, as a public client" do
    expect(run_flow(:chatgpt, "https://chatgpt.com/connector_platform_oauth_redirect", none)).to include("access_token")
  end

  scenario "ChatGPT, on a server offering private_key_jwt, with its key" do
    config_is_set(:client_authentication, %i[none private_key_jwt])

    expect(run_flow(:chatgpt, "https://chatgpt.com/connector_platform_oauth_redirect", private_key_jwt)).to include("access_token")
  end

  scenario "ChatGPT, on a server offering private_key_jwt, is refused without its key" do
    config_is_set(:client_authentication, %i[none private_key_jwt])
    callback = authorization_response("https://chatgpt.com/oauth/client.json", "https://chatgpt.com/connector_platform_oauth_redirect")

    expect(token_request(grant_type: "authorization_code", code: callback.fetch("code"), client_id: "https://chatgpt.com/oauth/client.json",
                         redirect_uri: "https://chatgpt.com/connector_platform_oauth_redirect", code_verifier: code_verifier,))
      .to include("error" => "invalid_client")
  end
end
