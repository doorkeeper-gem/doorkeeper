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

  scenario "is advertised in the authorization server metadata" do
    visit "/.well-known/oauth-authorization-server"

    expect(JSON.parse(page.body)).to include("client_id_metadata_document_supported" => true)
  end

  scenario "a client authorizes and exchanges its code with its URL as client_id" do
    authorize
    i_should_see "Example MCP (client.example.com)"
    click_on "Authorize"

    code = Rack::Utils.parse_query(URI.parse(current_url).query)["code"]
    page.driver.post token_endpoint_url, grant_type: "authorization_code", code: code, client_id: client_id, redirect_uri: redirect_uri

    expect(JSON.parse(page.body)).to include("access_token", "token_type" => "Bearer")
  end

  scenario "a redirect_uri the server refuses is dropped, not the whole client" do
    document[:redirect_uris] = ["http://client.example.com/callback", redirect_uri]
    authorize

    i_should_see "Example MCP (client.example.com)"
  end

  scenario "a redirect_uri the document does not list is refused" do
    authorize(redirect_uri: "https://evil.example.com/callback")

    i_should_see_translated_error_message :invalid_redirect_uri
  end

  scenario "a document naming another client_id is refused" do
    document[:client_id] = "https://other.example.com/metadata.json"
    authorize

    i_should_see_translated_error_message :invalid_client
  end

  scenario "a document asking for a shared secret is refused" do
    document[:token_endpoint_auth_method] = "client_secret_basic"
    authorize

    i_should_see_translated_error_message :invalid_client
  end

  scenario "the scopes are capped by the configuration" do
    config_is_set(:client_id_metadata_document_scopes, %w[public])
    authorize(scope: "write")

    i_should_see_translated_error_message :invalid_scope
  end

  scenario "the client_credentials grant is refused" do
    Doorkeeper::OAuth::ClientIdMetadataDocument.application(client_id)
    page.driver.post token_endpoint_url, grant_type: "client_credentials", client_id: client_id

    expect(JSON.parse(page.body)).to include("error" => "invalid_client")
  end

  scenario "an https client_id is an ordinary one while the option is off" do
    config_is_set(:use_client_id_metadata_documents, false)
    authorize

    i_should_see_translated_error_message :invalid_client
    expect(a_request(:get, client_id)).not_to have_been_made
  end
end
