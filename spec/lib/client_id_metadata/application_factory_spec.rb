# frozen_string_literal: true

require "spec_helper"

RSpec.describe Doorkeeper::ClientIdMetadata::ApplicationFactory do
  let(:url) { "https://client.example.com/oauth-client" }

  def document(attributes = {})
    Doorkeeper::ClientIdMetadata::Document.new(
      url,
      {
        "client_id" => url,
        "client_name" => "Example App",
        "redirect_uris" => ["https://app.example.com/callback"],
        "token_endpoint_auth_method" => "none",
      }.merge(attributes).compact,
    )
  end

  describe ".upsert" do
    it "creates an application row keyed by the client_id URL" do
      application = described_class.upsert(document)

      expect(application).to be_persisted
      expect(application.uid).to eq(url)
      expect(application.name).to eq("Example App")
      expect(application.redirect_uri).to eq("https://app.example.com/callback")
      expect(application.confidential).to be false
    end

    it "joins multiple redirect_uris with newlines" do
      application = described_class.upsert(
        document("redirect_uris" => ["https://app.example.com/a", "https://app.example.com/b"]),
      )

      expect(application.redirect_uri).to eq("https://app.example.com/a\nhttps://app.example.com/b")
    end

    it "carries the document's scope over to the application" do
      application = described_class.upsert(document("scope" => "read"))

      expect(application.scopes.to_s).to eq("read")
    end

    it "leaves the application on the server's default scopes when the document declares none" do
      expect(described_class.upsert(document).scopes.to_s).to eq("")
    end

    # Otherwise a client that drops the property keeps the narrower scope of
    # the document it was first resolved from.
    it "widens the scope back when the document stops declaring one" do
      described_class.upsert(document("scope" => "read"))
      application = described_class.upsert(document)

      expect(application.scopes.to_s).to eq("")
    end

    it "falls back to the host when client_name is absent" do
      application = described_class.upsert(document("client_name" => nil))

      expect(application.name).to eq("client.example.com")
    end

    it "updates the existing row on subsequent resolutions" do
      first = described_class.upsert(document)
      second = described_class.upsert(document("client_name" => "Renamed App"))

      expect(second.id).to eq(first.id)
      expect(second.name).to eq("Renamed App")
      expect(Doorkeeper::Application.where(uid: url).count).to eq(1)
    end

    it "returns nil when the resulting application is invalid" do
      # Default configuration requires a redirect_uri for authorization_code.
      expect(described_class.upsert(document("redirect_uris" => nil))).to be_nil
    end

    it "performs the write through the primary role" do
      # Rails routes the authorization endpoint's GET to a read replica when
      # automatic role switching is on, so the row must be written explicitly
      # against the primary.
      expect(Doorkeeper.config.application_model).to receive(:with_primary_role).and_call_original

      expect(described_class.upsert(document)).to be_persisted
    end

    it "returns the winning row when a concurrent resolution raced on the uid" do
      existing = described_class.upsert(document)
      allow(Doorkeeper.config.application_model)
        .to receive(:find_or_initialize_by).and_raise(ActiveRecord::RecordNotUnique, "duplicate uid")

      expect(described_class.upsert(document).id).to eq(existing.id)
    end

    # name and scopes are string columns, which MySQL sizes at 255 characters,
    # so an over-long document value is refused by the database rather than by
    # a model validation. The document comes from whoever hosts the client_id
    # URL, so that has to reject the client instead of raising.
    it "returns nil when the database refuses the row" do
      allow(Doorkeeper.config.application_model)
        .to receive(:find_or_initialize_by)
        .and_raise(ActiveRecord::ValueTooLong.new("Data too long for column 'name'"))

      expect(described_class.upsert(document)).to be_nil
    end

    it "does not swallow unrelated errors" do
      allow(Doorkeeper.config.application_model)
        .to receive(:find_or_initialize_by).and_raise(ArgumentError, "boom")

      expect { described_class.upsert(document) }.to raise_error(ArgumentError, "boom")
    end

    it "does not touch registered applications with other uids" do
      registered = FactoryBot.create(:application)

      described_class.upsert(document)

      expect(registered.reload.uid).not_to eq(url)
    end
  end
end
