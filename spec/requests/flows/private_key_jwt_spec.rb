# frozen_string_literal: true

require "spec_helper"
require "jwt"

feature "private_key_jwt client authentication" do
  let(:redirect_uri) { "https://app.example.com/callback" }
  let(:rsa_key) { OpenSSL::PKey::RSA.generate(2048) }
  let(:kid) { "sig-key" }
  let(:jwk) { JWT::JWK.new(rsa_key.public_key, { kid: kid }) }
  let(:jwks) { { "keys" => [jwk.export] } }
  let(:token_endpoint_audience) { "http://www.example.com/oauth/token" }

  background do
    config_is_set(:client_authentication, %i[client_secret_basic client_secret_post none private_key_jwt])
    default_scopes_exist :default
    config_is_set(:authenticate_resource_owner) { User.first || redirect_to("/sign_in") }
    create_resource_owner
    sign_in

    client_exists(
      name: "Confidential Example App",
      redirect_uri: redirect_uri,
      confidential: true,
      jwks: jwks.to_json,
    )

    allow(Resolv).to receive(:getaddresses).and_return(["93.184.216.34"])
  end

  def client_assertion(key: rsa_key, header_kid: kid, claims: {})
    JWT.encode(
      {
        "iss" => @client.uid,
        "sub" => @client.uid,
        "aud" => token_endpoint_audience,
        "exp" => Time.now.to_i + 60,
        "jti" => SecureRandom.hex(8),
      }.merge(claims),
      key,
      "RS256",
      { "kid" => header_kid },
    )
  end

  # When a matching token already exists (e.g. a second run within one
  # scenario) the authorization endpoint skips the consent screen and
  # redirects straight back with a fresh code.
  def authorize_and_return_code
    visit authorization_endpoint_url(client_id: @client.uid, redirect_uri: redirect_uri)
    click_on "Authorize" if current_params["code"].blank?
    current_params["code"]
  end

  def post_token(code, extra_params = {})
    page.driver.post token_endpoint_url, {
      grant_type: "authorization_code",
      code: code,
      redirect_uri: redirect_uri,
      client_id: @client.uid,
    }.merge(extra_params)
  end

  scenario "a confidential client authenticates the token request with a signed assertion" do
    code = authorize_and_return_code

    post_token(
      code,
      client_assertion: client_assertion,
      client_assertion_type: Doorkeeper::OAuth::ClientAuthentication::PrivateKeyJwt::CLIENT_ASSERTION_TYPE,
    )

    expect(page.driver.response.status).to eq(200)
    expect(json_response).to include("access_token" => Doorkeeper::AccessToken.first.token)
    expect(Doorkeeper::AccessToken.first.application.uid).to eq(@client.uid)
  end

  # RFC 7523 §2.2 is what private_key_jwt implements, and client_credentials
  # is the shortest end-to-end demonstration of it: no resource owner, no
  # browser step, so the assertion is the only thing standing in for the
  # client secret the client never has.
  context "when the client uses the client_credentials grant" do
    background do
      config_is_set(:grant_flows, %w[client_credentials])
    end

    def post_client_credentials(assertion)
      page.driver.post token_endpoint_url, {
        grant_type: "client_credentials",
        client_assertion: assertion,
        client_assertion_type: Doorkeeper::OAuth::ClientAuthentication::PrivateKeyJwt::CLIENT_ASSERTION_TYPE,
      }
    end

    scenario "a signed assertion authenticates the request with no client secret sent" do
      post_client_credentials(client_assertion)

      expect(page.driver.response.status).to eq(200)
      token = Doorkeeper::AccessToken.first
      expect(json_response).to include("access_token" => token.token)
      expect(token.application_id).to eq(@client.id)
    end

    scenario "an assertion signed with a key the client did not publish is rejected" do
      post_client_credentials(client_assertion(key: OpenSSL::PKey::RSA.generate(2048)))

      expect(page.driver.response.status).to eq(401)
      expect(json_response).to include("error" => "invalid_client")
      expect(Doorkeeper::AccessToken.count).to eq(0)
    end
  end

  context "when the refresh token grant is enabled" do
    background do
      config_is_set(:refresh_token_enabled, true)
      config_is_set(:grant_flows, %w[authorization_code refresh_token])
    end

    scenario "a confidential client refreshes with a signed assertion" do
      post_token(
        authorize_and_return_code,
        client_assertion: client_assertion,
        client_assertion_type: Doorkeeper::OAuth::ClientAuthentication::PrivateKeyJwt::CLIENT_ASSERTION_TYPE,
      )
      expect(page.driver.response.status).to eq(200)
      refresh_token = json_response["refresh_token"]
      expect(refresh_token).to be_present

      page.driver.post token_endpoint_url, {
        grant_type: "refresh_token",
        refresh_token: refresh_token,
        client_id: @client.uid,
        client_assertion: client_assertion,
        client_assertion_type: Doorkeeper::OAuth::ClientAuthentication::PrivateKeyJwt::CLIENT_ASSERTION_TYPE,
      }

      expect(page.driver.response.status).to eq(200)
      expect(json_response).to have_key("access_token")
      expect(json_response["refresh_token"]).not_to eq(refresh_token)
    end
  end

  scenario "keys can also be fetched from the application's jwks_uri" do
    jwks_uri = "https://client.example.com/jwks.json"
    @client.update!(jwks: nil, jwks_uri: jwks_uri)
    stub_request(:get, jwks_uri).to_return(status: 200, body: jwks.to_json)

    code = authorize_and_return_code
    post_token(
      code,
      client_assertion: client_assertion,
      client_assertion_type: Doorkeeper::OAuth::ClientAuthentication::PrivateKeyJwt::CLIENT_ASSERTION_TYPE,
    )

    expect(page.driver.response.status).to eq(200)
    expect(json_response).to have_key("access_token")
  end

  # The jwks_uri names a host the client controls, so its answers get the
  # same treatment as any other client-published input: a rejected client,
  # never an exception out of the token endpoint.
  scenario "a jwks_uri host that does not speak HTTP is rejected, not raised" do
    jwks_uri = "https://client.example.com/jwks.json"
    @client.update!(jwks: nil, jwks_uri: jwks_uri)
    stub_request(:get, jwks_uri).to_raise(Net::HTTPBadResponse.new('wrong status line: "NOT-HTTP"'))

    code = authorize_and_return_code
    post_token(
      code,
      client_assertion: client_assertion,
      client_assertion_type: Doorkeeper::OAuth::ClientAuthentication::PrivateKeyJwt::CLIENT_ASSERTION_TYPE,
    )

    expect(page.driver.response.status).to eq(401)
    expect(json_response["error"]).to eq("invalid_client")
  end

  scenario "a confidential client cannot exchange the code without authentication" do
    code = authorize_and_return_code

    post_token(code)

    expect(page.driver.response.status).to eq(401)
    expect(json_response["error"]).to eq("invalid_client")
  end

  scenario "an assertion signed with a key outside the published jwks is rejected" do
    code = authorize_and_return_code

    post_token(
      code,
      client_assertion: client_assertion(key: OpenSSL::PKey::RSA.generate(2048)),
      client_assertion_type: Doorkeeper::OAuth::ClientAuthentication::PrivateKeyJwt::CLIENT_ASSERTION_TYPE,
    )

    expect(page.driver.response.status).to eq(401)
    expect(json_response["error"]).to eq("invalid_client")
  end

  scenario "a replayed assertion is rejected" do
    assertion = client_assertion

    first_code = authorize_and_return_code
    post_token(
      first_code,
      client_assertion: assertion,
      client_assertion_type: Doorkeeper::OAuth::ClientAuthentication::PrivateKeyJwt::CLIENT_ASSERTION_TYPE,
    )
    expect(page.driver.response.status).to eq(200)

    second_code = authorize_and_return_code
    post_token(
      second_code,
      client_assertion: assertion,
      client_assertion_type: Doorkeeper::OAuth::ClientAuthentication::PrivateKeyJwt::CLIENT_ASSERTION_TYPE,
    )

    expect(page.driver.response.status).to eq(401)
    expect(json_response["error"]).to eq("invalid_client")
  end

  scenario "private_key_jwt is advertised in the authorization server metadata" do
    page.driver.get "/.well-known/oauth-authorization-server"

    expect(json_response["token_endpoint_auth_methods_supported"]).to include("private_key_jwt")
  end

  # OIDC Core §9 says the audience SHOULD be the token endpoint URL, so a
  # compliant client sends that value when authenticating at the revocation
  # and introspection endpoints too.
  scenario "the token endpoint audience is accepted at the revocation endpoint" do
    code = authorize_and_return_code
    post_token(
      code,
      client_assertion: client_assertion,
      client_assertion_type: Doorkeeper::OAuth::ClientAuthentication::PrivateKeyJwt::CLIENT_ASSERTION_TYPE,
    )
    expect(page.driver.response.status).to eq(200)

    token = Doorkeeper::AccessToken.last
    page.driver.post "/oauth/revoke", {
      token: token.token,
      client_id: @client.uid,
      client_assertion: client_assertion,
      client_assertion_type: Doorkeeper::OAuth::ClientAuthentication::PrivateKeyJwt::CLIENT_ASSERTION_TYPE,
    }

    expect(page.driver.response.status).to eq(200)
    expect(token.reload).to be_revoked
  end

  scenario "the endpoint's own URL is still accepted as audience" do
    code = authorize_and_return_code
    post_token(
      code,
      client_assertion: client_assertion,
      client_assertion_type: Doorkeeper::OAuth::ClientAuthentication::PrivateKeyJwt::CLIENT_ASSERTION_TYPE,
    )
    expect(page.driver.response.status).to eq(200)

    token = Doorkeeper::AccessToken.last
    revocation_audience = "http://www.example.com/oauth/revoke"
    page.driver.post "/oauth/revoke", {
      token: token.token,
      client_id: @client.uid,
      client_assertion: client_assertion(claims: { "aud" => revocation_audience }),
      client_assertion_type: Doorkeeper::OAuth::ClientAuthentication::PrivateKeyJwt::CLIENT_ASSERTION_TYPE,
    }

    expect(page.driver.response.status).to eq(200)
    expect(token.reload).to be_revoked
  end

  scenario "an assertion for an unrelated audience is rejected" do
    code = authorize_and_return_code

    post_token(
      code,
      client_assertion: client_assertion(claims: { "aud" => "https://someone-else.example.com/token" }),
      client_assertion_type: Doorkeeper::OAuth::ClientAuthentication::PrivateKeyJwt::CLIENT_ASSERTION_TYPE,
    )

    expect(page.driver.response.status).to eq(401)
    expect(json_response["error"]).to eq("invalid_client")
  end

  context "with a client ID metadata document client" do
    let(:client_id_url) { "https://client.example.com/oauth-client" }
    let(:metadata) do
      {
        "client_id" => client_id_url,
        "client_name" => "Confidential Example App",
        "redirect_uris" => [redirect_uri],
        "token_endpoint_auth_method" => "private_key_jwt",
        "jwks" => jwks,
      }
    end

    background do
      config_is_set(:client_id_metadata_documents, true)
      # A document client's audience is never derived from the request, so the
      # server has to identify itself for its assertions to be verifiable at
      # all — see PrivateKeyJwt.acceptable_audiences.
      config_is_set(:issuer, "http://www.example.com")
      Doorkeeper::ClientIdMetadata.document_cache.clear
      stub_request(:get, client_id_url).to_return(status: 200, body: metadata.to_json)
    end

    def client_assertion(key: rsa_key, header_kid: kid, claims: {})
      super(key: key, header_kid: header_kid, claims: { "iss" => client_id_url, "sub" => client_id_url }.merge(claims))
    end

    def authorize_and_return_code
      visit authorization_endpoint_url(client_id: client_id_url, redirect_uri: redirect_uri)
      click_on "Authorize" if current_params["code"].blank?
      current_params["code"]
    end

    def post_token(code, extra_params = {})
      page.driver.post token_endpoint_url, {
        grant_type: "authorization_code",
        code: code,
        redirect_uri: redirect_uri,
        client_id: client_id_url,
      }.merge(extra_params)
    end

    scenario "a confidential URL client authenticates the token request with a signed assertion" do
      code = authorize_and_return_code

      application = Doorkeeper::Application.find_by(uid: client_id_url)
      expect(application.confidential).to be true

      post_token(
        code,
        client_assertion: client_assertion,
        client_assertion_type: Doorkeeper::OAuth::ClientAuthentication::PrivateKeyJwt::CLIENT_ASSERTION_TYPE,
      )

      expect(page.driver.response.status).to eq(200)
      expect(json_response).to have_key("access_token")
      expect(Doorkeeper::AccessToken.last.application.uid).to eq(client_id_url)
    end

    # A document client_id resolves to the same client, and the same keys, at
    # every server implementing the draft, so an audience taken from the Host
    # header would make one server's assertion replayable at all of them.
    scenario "a URL client is refused when the server identifies itself nowhere" do
      config_is_set(:issuer, nil)
      code = authorize_and_return_code

      post_token(
        code,
        client_assertion: client_assertion(claims: { "aud" => token_endpoint_audience }),
        client_assertion_type: Doorkeeper::OAuth::ClientAuthentication::PrivateKeyJwt::CLIENT_ASSERTION_TYPE,
      )

      expect(page.driver.response.status).to eq(401)
      expect(json_response["error"]).to eq("invalid_client")
    end

    scenario "keys can also be fetched from the document's jwks_uri" do
      jwks_uri = "https://client.example.com/jwks.json"
      stub_request(:get, client_id_url)
        .to_return(status: 200, body: metadata.except("jwks").merge("jwks_uri" => jwks_uri).to_json)
      stub_request(:get, jwks_uri).to_return(status: 200, body: jwks.to_json)

      code = authorize_and_return_code
      post_token(
        code,
        client_assertion: client_assertion,
        client_assertion_type: Doorkeeper::OAuth::ClientAuthentication::PrivateKeyJwt::CLIENT_ASSERTION_TYPE,
      )

      expect(page.driver.response.status).to eq(200)
      expect(json_response).to have_key("access_token")
    end

    context "when the refresh token grant is enabled" do
      background do
        config_is_set(:refresh_token_enabled, true)
        config_is_set(:grant_flows, %w[authorization_code refresh_token])
      end

      scenario "a confidential URL client refreshes with a signed assertion" do
        post_token(
          authorize_and_return_code,
          client_assertion: client_assertion,
          client_assertion_type: Doorkeeper::OAuth::ClientAuthentication::PrivateKeyJwt::CLIENT_ASSERTION_TYPE,
        )
        expect(page.driver.response.status).to eq(200)
        refresh_token = json_response["refresh_token"]
        expect(refresh_token).to be_present

        page.driver.post token_endpoint_url, {
          grant_type: "refresh_token",
          refresh_token: refresh_token,
          client_id: client_id_url,
          client_assertion: client_assertion,
          client_assertion_type: Doorkeeper::OAuth::ClientAuthentication::PrivateKeyJwt::CLIENT_ASSERTION_TYPE,
        }

        expect(page.driver.response.status).to eq(200)
        expect(json_response).to have_key("access_token")
      end
    end

    # The keys come straight from an attacker-controlled document, and they
    # are resolved before the assertion's signature is checked, so a key the
    # jwt gem chokes on must fail authentication rather than reach the
    # endpoint as a 500. This set is well-formed enough to pass the document's
    # own validation, so it genuinely reaches the key resolver.
    context "when the document publishes a key the JWK parser cannot build" do
      let(:jwks) { { "keys" => [{ "kty" => "RSA", "kid" => kid, "n" => 123, "e" => "AQAB" }] } }

      scenario "the token endpoint rejects the client instead of raising" do
        visit authorization_endpoint_url(client_id: client_id_url, redirect_uri: redirect_uri)
        click_on "Authorize"
        code = current_params["code"]

        page.driver.post token_endpoint_url, {
          grant_type: "authorization_code",
          code: code,
          redirect_uri: redirect_uri,
          client_id: client_id_url,
          client_assertion: client_assertion,
          client_assertion_type: Doorkeeper::OAuth::ClientAuthentication::PrivateKeyJwt::CLIENT_ASSERTION_TYPE,
        }

        expect(page.driver.response.status).to eq(401)
        expect(json_response["error"]).to eq("invalid_client")
      end
    end

    context "when the document's jwks is malformed" do
      let(:jwks) { [jwk.export] }

      scenario "the invalid document rejects the client at the token endpoint" do
        visit authorization_endpoint_url(client_id: client_id_url, redirect_uri: redirect_uri)

        # The document itself is now invalid, so there is no client to consent to.
        expect(Doorkeeper::Application.find_by(uid: client_id_url)).to be_nil

        page.driver.post token_endpoint_url, {
          grant_type: "authorization_code",
          code: "irrelevant",
          redirect_uri: redirect_uri,
          client_id: client_id_url,
          client_assertion: client_assertion,
          client_assertion_type: Doorkeeper::OAuth::ClientAuthentication::PrivateKeyJwt::CLIENT_ASSERTION_TYPE,
        }

        expect(page.driver.response.status).to eq(401)
        expect(json_response["error"]).to eq("invalid_client")
      end
    end
  end
end
