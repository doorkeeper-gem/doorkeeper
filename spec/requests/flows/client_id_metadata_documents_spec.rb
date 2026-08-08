# frozen_string_literal: true

require "spec_helper"

feature "Client ID Metadata Documents" do
  let(:client_id_url) { "https://client.example.com/oauth-client" }
  let(:redirect_uri) { "https://app.example.com/callback" }
  let(:metadata) do
    {
      "client_id" => client_id_url,
      "client_name" => "Example App",
      "redirect_uris" => [redirect_uri],
      "token_endpoint_auth_method" => "none",
    }
  end

  background do
    config_is_set(:client_id_metadata_documents, true)
    default_scopes_exist :default
    config_is_set(:authenticate_resource_owner) { User.first || redirect_to("/sign_in") }
    create_resource_owner
    sign_in

    allow(Resolv).to receive(:getaddresses).and_return(["93.184.216.34"])
  end

  def stub_metadata_document(body = metadata.to_json, status: 200, headers: {})
    stub_request(:get, client_id_url).to_return(status: status, body: body, headers: headers)
  end

  scenario "a URL client completes the authorization code flow without pre-registration" do
    stub_metadata_document

    visit authorization_endpoint_url(client_id: client_id_url, redirect_uri: redirect_uri)

    i_should_see "Example App"
    click_on "Authorize"

    grant = Doorkeeper::AccessGrant.first
    expect(grant).not_to be_nil
    expect(grant.application.uid).to eq(client_id_url)

    expect(current_uri.host).to eq("app.example.com")
    code = current_params["code"]
    expect(code).to eq(grant.token)

    page.driver.post token_endpoint_url,
                     token_endpoint_params(code: code, client_id: client_id_url, redirect_uri: redirect_uri)

    expect(json_response).to include(
      "access_token" => Doorkeeper::AccessToken.first.token,
      "token_type" => "Bearer",
    )
    expect(Doorkeeper::AccessToken.first.application.uid).to eq(client_id_url)
  end

  scenario "the materialized application reflects the latest document" do
    stub_metadata_document

    visit authorization_endpoint_url(client_id: client_id_url, redirect_uri: redirect_uri)

    application = Doorkeeper::Application.find_by(uid: client_id_url)
    expect(application.name).to eq("Example App")
    expect(application.confidential).to be false

    # Re-resolved once the memo expires: the row must follow the document
    # rather than keep what it was first created from.
    Doorkeeper::ClientIdMetadata.document_cache.clear
    stub_metadata_document(metadata.merge("client_name" => "Renamed App").to_json)

    visit authorization_endpoint_url(client_id: client_id_url, redirect_uri: redirect_uri)

    expect(application.reload.name).to eq("Renamed App")
    expect(Doorkeeper::Application.where(uid: client_id_url).count).to eq(1)
  end

  # The document names both the authentication method and the keys, so a
  # confidential client that presents no credentials at all must be refused by
  # the row's own confidential flag.
  scenario "a confidential document client cannot get a token without authenticating" do
    stub_metadata_document(
      metadata.merge(
        "token_endpoint_auth_method" => "private_key_jwt",
        "jwks" => { "keys" => [{ "kty" => "RSA", "kid" => "k", "n" => "AA", "e" => "AQAB" }] },
      ).to_json,
    )
    config_is_set(:client_authentication, %i[client_secret_basic client_secret_post none private_key_jwt])

    visit authorization_endpoint_url(client_id: client_id_url, redirect_uri: redirect_uri)
    click_on "Authorize"
    code = current_params["code"]

    page.driver.post token_endpoint_url,
                     token_endpoint_params(code: code, client_id: client_id_url, redirect_uri: redirect_uri)

    expect(json_response).to include("error" => "invalid_client")
    expect(Doorkeeper::AccessToken.count).to eq(0)
  end

  # A client's own scopes replace the server's as the allow-list, so a
  # document naming a scope this server never configured must not resolve at
  # all — otherwise hosting a JSON file is enough to be issued a token for it.
  scenario "a document cannot grant itself a scope the server never configured" do
    stub_metadata_document(metadata.merge("scope" => "admin").to_json)

    visit authorization_endpoint_url(client_id: client_id_url, redirect_uri: redirect_uri)

    i_should_see_translated_error_message("invalid_client")
    expect(Doorkeeper::Application.count).to eq(0)
  end

  # Every entry point tests the feature flag for itself, so the token endpoint
  # needs its own pin: a disabled server must not fetch an attacker's URL.
  scenario "the token endpoint does not resolve URL client_ids while the feature is disabled" do
    config_is_set(:client_id_metadata_documents, false)
    request_stub = stub_metadata_document

    page.driver.post token_endpoint_url,
                     grant_type: "client_credentials", client_id: client_id_url

    expect(json_response).to include("error")
    expect(json_response).not_to have_key("access_token")
    expect(request_stub).not_to have_been_requested
  end

  # URI.parse accepts any integer as a port; Net::HTTP raises TypeError on one
  # too large to be a port, which no fetch is prepared for.
  scenario "a client_id whose port could never be connected to is rejected without a crash" do
    page.driver.post token_endpoint_url,
                     grant_type: "client_credentials",
                     client_id: "https://client.example.com:99999999999999999999/app"

    expect(json_response).to include("error" => "invalid_client")
  end

  scenario "pre-registered clients keep working while the feature is enabled" do
    client_exists

    visit authorization_endpoint_url(client: @client)
    click_on "Authorize"

    access_grant_should_exist_for(@client, @resource_owner)
  end

  scenario "URL client_ids are rejected while the feature is disabled" do
    config_is_set(:client_id_metadata_documents, false)
    request_stub = stub_metadata_document

    visit authorization_endpoint_url(client_id: client_id_url, redirect_uri: redirect_uri)

    i_should_see_translated_error_message("invalid_client")
    expect(request_stub).not_to have_been_requested
  end

  scenario "a client_id URL without a path component is rejected without fetching" do
    request_stub = stub_request(:get, "https://client.example.com/")

    visit authorization_endpoint_url(client_id: "https://client.example.com", redirect_uri: redirect_uri)

    i_should_see_translated_error_message("invalid_client")
    expect(request_stub).not_to have_been_requested
  end

  scenario "a host resolving to a special-use address is never fetched (SSRF)" do
    allow(Resolv).to receive(:getaddresses).and_return(["127.0.0.1"])
    request_stub = stub_metadata_document

    visit authorization_endpoint_url(client_id: client_id_url, redirect_uri: redirect_uri)

    i_should_see_translated_error_message("invalid_client")
    expect(request_stub).not_to have_been_requested
  end

  scenario "a redirecting metadata endpoint is treated as an error and not followed" do
    redirect_target = "https://elsewhere.example.com/metadata"
    stub_metadata_document(nil, status: 302, headers: { "Location" => redirect_target })
    target_stub = stub_request(:get, redirect_target)

    visit authorization_endpoint_url(client_id: client_id_url, redirect_uri: redirect_uri)

    i_should_see_translated_error_message("invalid_client")
    expect(target_stub).not_to have_been_requested
  end

  scenario "a non-200 metadata response is rejected" do
    stub_metadata_document("", status: 404)

    visit authorization_endpoint_url(client_id: client_id_url, redirect_uri: redirect_uri)

    i_should_see_translated_error_message("invalid_client")
  end

  # Everything the metadata host sends is chosen by whoever sent the client_id,
  # so no answer of theirs may surface as a server error.
  scenario "a metadata host that does not speak HTTP is rejected, not raised" do
    stub_request(:get, client_id_url).to_raise(Net::HTTPBadResponse.new('wrong status line: "NOT-HTTP"'))

    visit authorization_endpoint_url(client_id: client_id_url, redirect_uri: redirect_uri)

    i_should_see_translated_error_message("invalid_client")
  end

  scenario "a metadata document not served as JSON is rejected" do
    stub_metadata_document(headers: { "Content-Type" => "text/html" })

    visit authorization_endpoint_url(client_id: client_id_url, redirect_uri: redirect_uri)

    i_should_see_translated_error_message("invalid_client")
  end

  scenario "a document whose client_name would not fit the name column is rejected" do
    stub_metadata_document(metadata.merge("client_name" => "a" * 256).to_json)

    visit authorization_endpoint_url(client_id: client_id_url, redirect_uri: redirect_uri)

    i_should_see_translated_error_message("invalid_client")
  end

  scenario "a client_id URL too long for the uid column is rejected without fetching" do
    long_url = "https://client.example.com/#{"a" * 230}"
    request_stub = stub_request(:get, long_url)

    visit authorization_endpoint_url(client_id: long_url, redirect_uri: redirect_uri)

    i_should_see_translated_error_message("invalid_client")
    expect(request_stub).not_to have_been_requested
  end

  scenario "a document whose client_id does not match the URL is rejected" do
    stub_metadata_document(metadata.merge("client_id" => "https://other.example.com/client").to_json)

    visit authorization_endpoint_url(client_id: client_id_url, redirect_uri: redirect_uri)

    i_should_see_translated_error_message("invalid_client")
  end

  scenario "a document containing client_secret is rejected" do
    stub_metadata_document(metadata.merge("client_secret" => "s3cret").to_json)

    visit authorization_endpoint_url(client_id: client_id_url, redirect_uri: redirect_uri)

    i_should_see_translated_error_message("invalid_client")
  end

  scenario "a document declaring a shared-secret auth method is rejected" do
    stub_metadata_document(metadata.merge("token_endpoint_auth_method" => "client_secret_basic").to_json)

    visit authorization_endpoint_url(client_id: client_id_url, redirect_uri: redirect_uri)

    i_should_see_translated_error_message("invalid_client")
  end

  scenario "a redirect_uri outside the document's redirect_uris is rejected" do
    stub_metadata_document

    visit authorization_endpoint_url(client_id: client_id_url, redirect_uri: "https://evil.example.com/cb")

    i_should_see_translated_error_message("invalid_redirect_uri")
  end

  scenario "token requests with a client_secret cannot authenticate a URL client" do
    stub_metadata_document

    visit authorization_endpoint_url(client_id: client_id_url, redirect_uri: redirect_uri)
    click_on "Authorize"
    code = current_params["code"]

    page.driver.post token_endpoint_url,
                     token_endpoint_params(
                       code: code,
                       client_id: client_id_url,
                       client_secret: "guessed",
                       redirect_uri: redirect_uri,
                     )

    expect(page.driver.response.status).to eq(401)
    expect(json_response["error"]).to eq("invalid_client")
  end

  scenario "a matching client_secret from a pre-existing row cannot authenticate a URL client" do
    # An application registered with a URL uid and a known secret before the
    # feature was enabled: the secret must not become a valid credential.
    Doorkeeper::Application.create!(
      name: "Legacy",
      uid: client_id_url,
      secret: "legacy-secret",
      redirect_uri: redirect_uri,
    )
    stub_metadata_document

    visit authorization_endpoint_url(client_id: client_id_url, redirect_uri: redirect_uri)
    click_on "Authorize"
    code = current_params["code"]

    page.driver.post token_endpoint_url,
                     token_endpoint_params(
                       code: code,
                       client_id: client_id_url,
                       client_secret: "legacy-secret",
                       redirect_uri: redirect_uri,
                     )

    expect(page.driver.response.status).to eq(401)
    expect(json_response["error"]).to eq("invalid_client")
  end
end
