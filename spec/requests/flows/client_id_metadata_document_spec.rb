# frozen_string_literal: true

require "spec_helper"

feature "Client ID Metadata Documents" do
  let(:client_id) { "https://client.example.com/oauth/metadata.json" }
  let(:redirect_uri) { "https://client.example.com/callback" }
  let(:document) do
    { client_id: client_id, client_name: "Example MCP", redirect_uris: [redirect_uri], token_endpoint_auth_method: "none" }
  end

  background do
    Doorkeeper.configure do
      orm DOORKEEPER_ORM
      use_client_id_metadata_documents
    end
    default_scopes_exist :public
    optional_scopes_exist :write
    config_is_set(:authenticate_resource_owner) { User.first || redirect_to("/sign_in") }
    create_resource_owner
    sign_in
    Doorkeeper::OAuth::ClientIdMetadataDocument.cache.clear
    allow(Resolv).to receive(:getaddresses).and_return(["93.184.216.34"])
    stub_request(:get, client_id).to_return(status: 200, body: ->(_) { document.to_json })
  end

  def authorize(**params)
    visit authorization_endpoint_url(client_id: client_id, redirect_uri: redirect_uri, **params)
  end

  scenario "is advertised in the authorization server metadata (draft-02 §6)" do
    visit "/.well-known/oauth-authorization-server"

    expect(JSON.parse(page.body)).to include("client_id_metadata_document_supported" => true)
  end

  scenario "a client authorizes and exchanges its code with its URL as client_id (draft-02 §5)" do
    authorize
    i_should_see "client.example.com: Example MCP"
    click_on "Authorize"

    code = Rack::Utils.parse_query(URI.parse(current_url).query)["code"]
    page.driver.post token_endpoint_url, grant_type: "authorization_code", code: code, client_id: client_id, redirect_uri: redirect_uri

    expect(JSON.parse(page.body)).to include("access_token", "token_type" => "Bearer")
  end

  scenario "a redirect_uri the server refuses is dropped, not the whole client (draft-02 §8.1)" do
    document[:redirect_uris] = ["http://client.example.com/callback", "https://client.example.com/a b", redirect_uri]
    authorize

    i_should_see "client.example.com: Example MCP"
    expect(Doorkeeper::Application.by_uid(client_id).redirect_uri).to eq(redirect_uri)
  end

  scenario "without a client_name the host names the client (draft-02 §8.5)" do
    document.delete(:client_name)
    authorize

    expect(Doorkeeper::Application.by_uid(client_id).name).to eq("client.example.com")
  end

  scenario "a document whose redirect_uris are all refused is refused (draft-02 §4.2)" do
    document[:redirect_uris] = ["http://client.example.com/callback"]
    authorize

    i_should_see_translated_error_message :invalid_client
  end

  scenario "a redirect_uri the document does not list is refused (draft-02 §4.2)" do
    authorize(redirect_uri: "https://evil.example.com/callback")

    i_should_see_translated_error_message :invalid_redirect_uri
  end

  scenario "a document that cannot be fetched or parsed is refused (draft-02 §5.1)" do
    stub_request(:get, client_id).to_return({ status: 404 }, { status: 200, body: "not json" })

    2.times do
      Doorkeeper::OAuth::ClientIdMetadataDocument.cache.clear
      authorize
      i_should_see_translated_error_message :invalid_client
    end
  end

  scenario "a client_id that is no valid URI, or has dot segments, is an ordinary one (draft-02 §3)" do
    ["https://client example.com/metadata.json", "https://client.example.com/oauth/../metadata.json"].each do |url|
      visit authorization_endpoint_url(client_id: url, redirect_uri: redirect_uri)

      i_should_see_translated_error_message :invalid_client
    end
    expect(a_request(:get, /client.example.com/)).not_to have_been_made
  end

  scenario "a document naming another client_id is refused (draft-02 §4)" do
    document[:client_id] = "https://other.example.com/metadata.json"
    authorize

    i_should_see_translated_error_message :invalid_client
  end

  scenario "a document asking for a shared secret is refused (draft-02 §4.1)" do
    document[:token_endpoint_auth_method] = "client_secret_basic"
    authorize

    i_should_see_translated_error_message :invalid_client
  end

  scenario "a document naming no method is refused (draft-02 §4.1, RFC 7591 §2)" do
    document.delete(:token_endpoint_auth_method)
    authorize

    i_should_see_translated_error_message :invalid_client
  end

  scenario "the scopes, the document's own too, are capped by the configuration (RFC 6749 §3.3)" do
    config_is_set(:client_id_metadata_document_scopes, %w[public])

    [nil, "public write"].each do |scope|
      document[:scope] = scope
      Doorkeeper::OAuth::ClientIdMetadataDocument.cache.clear
      authorize(scope: "write")

      i_should_see_translated_error_message :invalid_scope
    end
  end

  scenario "without a cap the document's scope applies, else the default scopes, never all (RFC 6749 §3.3)" do
    document[:scope] = "public write"
    authorize(scope: "write")
    i_should_see "client.example.com: Example MCP"

    document.delete(:scope)
    Doorkeeper::OAuth::ClientIdMetadataDocument.cache.clear
    authorize(scope: "write")
    i_should_see_translated_error_message :invalid_scope

    config_is_set(:default_scopes, Doorkeeper::OAuth::Scopes.new)
    Doorkeeper::OAuth::ClientIdMetadataDocument.cache.clear
    Doorkeeper::Application.delete_all
    authorize(scope: "write")
    i_should_see_translated_error_message :invalid_client
  end

  scenario "a document whose scopes the configuration leaves nothing of is refused (RFC 6749 §3.3)" do
    config_is_set(:client_id_metadata_document_scopes, %w[public])
    document[:scope] = "write"
    authorize

    i_should_see_translated_error_message :invalid_client
  end

  scenario "a document whose scope or client_name is no string is refused (RFC 7591 §2)" do
    [{ scope: %w[public write] }, { client_name: { "en" => "Example" } }].each do |change|
      Doorkeeper::OAuth::ClientIdMetadataDocument.cache.clear
      stub_request(:get, client_id).to_return(status: 200, body: document.merge(change).to_json)
      authorize

      i_should_see_translated_error_message :invalid_client
    end
  end

  scenario "a changed document updates the client, an unfetchable one refuses it (draft-02 §5, §5.1)" do
    authorize
    document[:client_name] = "Renamed"
    Doorkeeper::OAuth::ClientIdMetadataDocument.cache.clear
    authorize
    i_should_see "client.example.com: Renamed"

    document[:redirect_uris] = ["http://client.example.com/callback"]
    Doorkeeper::OAuth::ClientIdMetadataDocument.cache.clear
    authorize
    i_should_see_translated_error_message :invalid_client

    stub_request(:get, client_id).to_return(status: 404)
    Doorkeeper::OAuth::ClientIdMetadataDocument.cache.clear
    authorize
    i_should_see_translated_error_message :invalid_client
  end

  scenario "a first request racing another one for the same client_id still gets the client" do
    allow(Doorkeeper::Application).to receive(:with_primary_role) do
      now = Time.current
      Doorkeeper::Application.insert({ uid: client_id, name: "client.example.com", secret: "secret", redirect_uri: redirect_uri,
                                       scopes: "public", confidential: false, client_id_metadata_materialized_at: now,
                                       created_at: now, updated_at: now, })
      raise ActiveRecord::RecordNotUnique
    end
    authorize

    i_should_see "client.example.com"
  end

  scenario "skip_authorization does not apply, the user always consents (draft-02 §8.5)" do
    config_is_set(:skip_authorization) { true }
    authorize

    i_should_see "client.example.com: Example MCP"
  end

  scenario "the client_credentials grant is refused, also once the option is off (RFC 6749 §4.4)" do
    Doorkeeper::OAuth::ClientIdMetadataDocument.application(client_id)

    [true, false].each do |enabled|
      config_is_set(:use_client_id_metadata_documents, enabled)
      page.driver.post token_endpoint_url, grant_type: "client_credentials", client_id: client_id

      expect(JSON.parse(page.body)).to include("error" => "invalid_client")
    end
  end

  scenario "a client known from its document is refused once the option is off (draft-02 §7.1)" do
    authorize
    click_on "Authorize"
    code = Rack::Utils.parse_query(URI.parse(current_url).query)["code"]
    config_is_set(:use_client_id_metadata_documents, false)

    page.driver.post token_endpoint_url, grant_type: "authorization_code", code: code, client_id: client_id, redirect_uri: redirect_uri
    expect(JSON.parse(page.body)).to include("error" => "invalid_client")

    authorize
    i_should_see_translated_error_message :invalid_client
  end

  scenario "a registered application with a URL as uid is used as registered, not fetched (draft-02 §7.2)" do
    [true, false].each do |confidential|
      Doorkeeper::Application.delete_all
      application = FactoryBot.create(:application, uid: client_id, confidential: confidential, redirect_uri: redirect_uri)
      authorize

      i_should_see application.name
      expect(application.reload).to have_attributes(confidential: confidential, client_id_metadata_materialized_at: nil)
    end
    expect(a_request(:get, client_id)).not_to have_been_made
  end

  scenario "an https client_id is an ordinary one while the option is off (draft-02 §7.1)" do
    config_is_set(:use_client_id_metadata_documents, false)
    authorize

    i_should_see_translated_error_message :invalid_client
    expect(a_request(:get, client_id)).not_to have_been_made
  end
end
