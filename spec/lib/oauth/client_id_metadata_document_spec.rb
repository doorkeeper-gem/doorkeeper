# frozen_string_literal: true

require "spec_helper"

RSpec.describe Doorkeeper::OAuth::ClientIdMetadataDocument do
  let(:client_id) { "https://client.example.com/oauth/metadata.json" }
  let(:redirect_uri) { "https://client.example.com/callback" }

  before do
    Doorkeeper.configure do
      orm DOORKEEPER_ORM
      use_client_id_metadata_documents
      default_scopes :public
    end
    described_class.cache.clear
    allow(Resolv).to receive(:getaddresses).and_return(["93.184.216.34"])
    stub_request(:get, client_id).to_return(
      status: 200,
      body: { client_id: client_id, redirect_uris: [redirect_uri], token_endpoint_auth_method: "none" }.to_json,
    )
  end

  it "keeps Module#name" do
    expect(described_class.name).to eq("Doorkeeper::OAuth::ClientIdMetadataDocument")
  end

  it "returns the row a concurrent first request wrote" do
    allow(Doorkeeper::Application).to receive(:with_primary_role) do
      now = Time.current
      Doorkeeper::Application.insert({ uid: client_id, name: "concurrent", secret: "secret", redirect_uri: redirect_uri,
                                       scopes: "public", confidential: false, client_id_metadata_materialized_at: now,
                                       created_at: now, updated_at: now, })
      raise ActiveRecord::RecordNotUnique
    end

    expect(described_class.application(client_id)).to have_attributes(name: "concurrent")
  end
end
