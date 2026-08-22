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

  # Makes the row the factory builds fail on save, which is where the database
  # reports the errors these examples simulate. The build is left to the model
  # so the stubbed row is otherwise a real one.
  def fail_save_with(error)
    model = Doorkeeper.config.application_model
    allow(model).to receive(:new).and_wrap_original do |original, *args, **kwargs|
      original.call(*args, **kwargs).tap { |row| allow(row).to receive(:save).and_raise(error) }
    end
  end

  # A lost race: the uid lookup misses, the insert then collides with the row
  # a concurrent resolution committed in between, and the recovery lookup
  # finds that row. The row validates before the insert — in the real race
  # the other row is not there yet when the uniqueness validation looks.
  def lose_race_with(error)
    model = Doorkeeper.config.application_model
    allow(model).to receive(:new).and_wrap_original do |original, *args, **kwargs|
      original.call(*args, **kwargs).tap do |row|
        allow(row).to receive_messages(valid?: true)
        allow(row).to receive(:save).and_raise(error)
      end
    end
    model = Doorkeeper.config.application_model
    lookups = 0
    allow(model).to receive(:by_uid).and_wrap_original do |original, *args|
      (lookups += 1) == 1 ? nil : original.call(*args)
    end
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

    # The row is re-assigned from the document on every resolution; when
    # nothing changed, ActiveRecord's dirty tracking must turn that into no
    # write at all.
    it "does not write the row when the document is unchanged" do
      first = described_class.upsert(document)
      original_updated_at = first.reload.updated_at

      Timecop.freeze(1.hour.from_now) do
        second = described_class.upsert(document)

        expect(second.id).to eq(first.id)
        expect(second.reload.updated_at).to eq(original_updated_at)
      end
    end

    # The uid lookup delegates the comparison to the database, whose collation
    # may be case-insensitive (MySQL's default is). A row that came back for a
    # different string is another client's, and writing this document's
    # attributes over it would merge the two.
    it "refuses a row whose uid is not byte-identical to the client_id" do
      other = FactoryBot.create(:application, uid: url.upcase)
      allow(Doorkeeper.config.application_model).to receive(:by_uid).with(url).and_return(other)

      expect(described_class.upsert(document)).to be_nil
      expect(other.reload.name).not_to eq("Example App")
    end

    # A row first materialized from a "none" document is created without a
    # secret where the column allows it; turning confidential later makes the
    # model require one, and it only generates a secret on create.
    it "gives a row that turns confidential the secret the model now requires" do
      config_is_set(:client_authentication, %i[none private_key_jwt])
      public_row = described_class.upsert(document)
      public_row.update_column(:secret, nil)

      confidential = described_class.upsert(
        document(
          "token_endpoint_auth_method" => "private_key_jwt",
          "jwks" => { "keys" => [{ "kty" => "RSA", "n" => "x", "e" => "AQAB" }] },
        ),
      )

      expect(confidential).not_to be_nil
      expect(confidential.id).to eq(public_row.id)
      expect(confidential.confidential).to be true
      expect(confidential.reload.secret).to be_present
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
      lose_race_with(ActiveRecord::RecordNotUnique.new("duplicate uid"))

      expect(described_class.upsert(document).id).to eq(existing.id)
    end

    it "reads the winning row through the primary role" do
      # The race winner committed only a moment ago, so a replica routed by
      # automatic role switching may not have the row yet — the recovery read
      # must be pinned to the primary like the write, or a valid concurrent
      # resolution is reported as invalid_client.
      described_class.upsert(document)
      lose_race_with(ActiveRecord::RecordNotUnique.new("duplicate uid"))

      expect(Doorkeeper.config.application_model)
        .to receive(:with_primary_role).twice.and_call_original

      expect(described_class.upsert(document)).to be_persisted
    end

    # name and scopes are string columns, which MySQL sizes at 255 characters,
    # so an over-long document value is refused by the database rather than by
    # a model validation. The document comes from whoever hosts the client_id
    # URL, so that has to reject the client instead of raising.
    it "returns nil when the database refuses the row" do
      fail_save_with(ActiveRecord::ValueTooLong.new("Data too long for column 'name'"))

      expect(described_class.upsert(document)).to be_nil
    end

    it "does not swallow unrelated errors" do
      fail_save_with(ArgumentError.new("boom"))

      expect { described_class.upsert(document) }.to raise_error(ArgumentError, "boom")
    end

    # These are statement failures too, but they say nothing about the
    # document: disguising them as invalid_client would hide a database
    # incident behind a client error nobody investigates.
    [
      ["a deadlock", ActiveRecord::Deadlocked],
      ["a lock wait timeout", ActiveRecord::LockWaitTimeout],
      ["a cancelled query", ActiveRecord::QueryCanceled],
      ["a serialization failure", ActiveRecord::SerializationFailure],
    ].each do |description, error_class|
      it "does not disguise #{description} as a rejected client" do
        fail_save_with(error_class.new("boom"))

        expect { described_class.upsert(document) }.to raise_error(error_class)
      end
    end

    # The unique index that reported the race is the database's, and its
    # collation need not be case-sensitive, so the row the winner committed
    # may belong to a client_id that only looks equal to this one.
    it "refuses a race winner whose uid is not byte-identical" do
      other = FactoryBot.create(:application, uid: url.upcase)
      lose_race_with(ActiveRecord::RecordNotUnique.new("duplicate uid"))
      allow(Doorkeeper.config.application_model).to receive(:by_uid).with(url).and_return(nil, other)

      expect(described_class.upsert(document)).to be_nil
    end

    it "does not touch registered applications with other uids" do
      registered = FactoryBot.create(:application)

      described_class.upsert(document)

      expect(registered.reload.uid).not_to eq(url)
    end

    # A document client is registered by no one, so there is no owner to
    # assign and its row cannot satisfy the validation. That is what
    # Config::Validations warns about at boot; pinned here so the warning
    # cannot outlive the behaviour.
    #
    # The mixin includes Ownership only when the feature is enabled as the
    # model class is defined, so the model has to be built after configuring
    # (see ApplicationModelHelper) — and built before Doorkeeper.config is
    # stubbed, since configuring replaces the object the stub would be on.
    context "when application ownership is enforced" do
      before do
        Doorkeeper.configure do
          orm DOORKEEPER_ORM
          enable_application_owner confirmation: true
        end
        owned = build_application_model(name: "OwnedApplication")

        allow(Doorkeeper.config).to receive(:application_model).and_return(owned)
      end

      it "cannot materialize a document client" do
        expect(described_class.upsert(document)).to be_nil
      end
    end
  end
end
