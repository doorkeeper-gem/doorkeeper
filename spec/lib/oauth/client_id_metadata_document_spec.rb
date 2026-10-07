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

  def insert_row(uid, materialized_at: Time.current)
    now = Time.current
    Doorkeeper::Application.insert({ uid: uid, name: "concurrent", secret: "secret", redirect_uri: redirect_uri,
                                     scopes: "public", confidential: false, client_id_metadata_materialized_at: materialized_at,
                                     created_at: now, updated_at: now, })
  end

  # The first write loses to a concurrent first request that wrote +uid+; later calls run as usual.
  def lose_first_write_to(uid)
    calls = 0
    allow(Doorkeeper::Application).to receive(:with_primary_role).and_wrap_original do |original, &block|
      next original.call(&block) unless (calls += 1) == 1

      insert_row(uid)
      raise ActiveRecord::RecordNotUnique
    end
  end

  it "returns the row a concurrent first request wrote" do
    lose_first_write_to(client_id)

    expect(described_class.application(client_id)).to have_attributes(name: "concurrent")
  end

  it "returns the row a concurrent first request committed before this one validated" do
    insert_row(client_id)
    calls = 0
    allow(Doorkeeper::Application).to receive(:by_uid).and_wrap_original do |original, uid|
      original.call(uid) unless (calls += 1) == 1
    end

    expect(described_class.application(client_id)).to have_attributes(name: "concurrent")
  end

  it "refuses a known client whose update fails rather than returning it unsaved" do
    insert_row(client_id, materialized_at: 1.day.ago)
    row = Doorkeeper::Application.find_by(uid: client_id)
    allow(Doorkeeper::Application).to receive(:by_uid).and_return(row)
    allow(row).to receive(:save).and_return(false)

    expect(described_class.application(client_id)).to be_nil
  end

  it "does not take a concurrent row for another client_id that a loose collation matches" do
    allow(Doorkeeper::Application).to receive(:by_uid) do |uid|
      Doorkeeper::Application.all.find { |application| application.uid.casecmp?(uid.to_s) }
    end
    lose_first_write_to(client_id.sub("oauth", "OAuth"))

    expect(described_class.application(client_id)).to be_nil
  end
end
