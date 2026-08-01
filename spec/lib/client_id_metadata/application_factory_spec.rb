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

  # Each supported ORM answers "is this row unchanged?" differently, and the
  # one that answers #modified? is also the one whose #save writes every
  # column — so getting its branch wrong is what turns every resolution into
  # a full UPDATE. Asked directly, since only ActiveRecord's branch is
  # reachable through the dummy app.
  describe "recognising an unchanged row across ORMs" do
    def unchanged?(row)
      described_class.send(:persisted_and_unchanged?, row)
    end

    it "reads Sequel's #modified?" do
      expect(unchanged?(double(new?: false, modified?: false))).to be(true)
      expect(unchanged?(double(new?: false, modified?: true))).to be(false)
    end

    it "treats a new Sequel row as one that has to be saved" do
      expect(unchanged?(double(new?: true, modified?: false))).to be(false)
    end

    it "saves when the model answers neither question" do
      expect(unchanged?(Object.new)).to be(false)
    end
  end

  # The affordances this file reaches for are ActiveRecord's, and each is
  # asked for by name so a model from another ORM extension keeps working
  # without it.
  describe "working without ActiveRecord's affordances" do
    it "runs the write directly when the model has no primary role to switch to" do
      model = double("model")

      expect(described_class.send(:on_primary, model) { :done }).to eq(:done)
    end

    it "saves without a savepoint when the model is not an ActiveRecord one" do
      application = double("application", save: true)

      expect(described_class.send(:save_row, double("model"), application, nil)).to be(true)
    end

    # The locking re-read is Active Record's, so a model from another ORM
    # extension is taken at its word the way it was before.
    it "confirms the provenance without a locking read for a non-ActiveRecord model" do
      existing = double("application", save: true)

      expect(described_class.send(:save_row, double("model"), existing, existing)).to be(true)
    end

    it "logs a row's refusal when its errors do not answer #full_messages" do
      application = double("application", errors: :unreadable)
      expect(Rails.logger).to receive(:warn).with(/unreadable/)

      described_class.send(:log_invalid_row, document, application)
    end

    it "leaves a confidential row alone when the model cannot renew a secret" do
      application = double("application", confidential: true, secret: nil)

      expect { described_class.send(:ensure_secret, application) }.not_to raise_error
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

    # Not "the server's default scopes": ScopeChecker reads an application's
    # scopes as the allow-list in place of the server's, so a blank column is
    # every scope the server configures, optional_scopes included.
    it "leaves the application without a scope restriction when the document declares none" do
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
    # write at all. This is the half of it dirty tracking answers for — that
    # re-assigning leaves the row clean; the example further down
    # ("does not write the row again ...") is the half that keeps an
    # unchanged row from reaching #save at all, which is what the ORMs
    # writing every column need.
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
      # Stamped, so the provenance check has nothing to say and the
      # byte-for-byte comparison is the only thing between this document and
      # another client's row.
      other = FactoryBot.create(
        :application,
        uid: url.upcase,
        client_id_metadata_materialized_at: Time.now.utc,
      )
      allow(Doorkeeper.config.application_model).to receive(:by_uid).with(url).and_return(other)

      expect(described_class.upsert(document)).to be_nil
      expect(other.reload.name).not_to eq("Example App")
    end

    # The https:// prefix alone does not make a row this feature's (draft
    # Section 7.1): a host application may have given a registered
    # application a URL-shaped uid — a vanity identifier, or a document
    # client registered by hand. Refreshing that row from whatever its URL
    # serves would hand it, with every grant and token still attached, to
    # whoever controls the URL.
    it "refuses a registered application whose uid was manually set to the client_id URL" do
      registered = FactoryBot.create(:application, uid: url)
      original_name = registered.name

      expect(described_class.upsert(document)).to be_nil
      expect(registered.reload.name).to eq(original_name)
    end

    # The stamp is the provenance the example above reads; only its absence
    # means anything, so a later resolution must not move it.
    it "stamps the rows it materializes, once" do
      first = described_class.upsert(document)
      stamp = first.reload.client_id_metadata_materialized_at

      expect(stamp).to be_present

      Timecop.freeze(1.hour.from_now) do
        described_class.upsert(document("client_name" => "Renamed App"))
      end

      expect(first.reload.client_id_metadata_materialized_at).to eq(stamp)
    end

    # Without the column there is no telling materialized rows apart from
    # registered applications, and adopting rows on the uid's shape alone is
    # the takeover the stamp exists to prevent — so the feature refuses
    # every document client, and says why.
    it "refuses every client when the application model lacks the stamp attribute" do
      model = Doorkeeper.config.application_model
      allow(model).to receive(:new).and_wrap_original do |original, *args, **kwargs|
        original.call(*args, **kwargs).tap do |row|
          allow(row).to receive(:respond_to?).and_call_original
          allow(row).to receive(:respond_to?)
            .with(:client_id_metadata_materialized_at).and_return(false)
        end
      end
      expect(Rails.logger).to receive(:warn).with(/client_id_metadata_materialized_at/)

      expect(described_class.upsert(document)).to be_nil
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

    # And says so in the log, like the other refusals in the factory: from
    # the outside, a document whose row fails validation answers the same
    # invalid_client a malformed one does.
    it "returns nil, and logs why, when the resulting application is invalid" do
      model = Doorkeeper.config.application_model
      allow(model).to receive(:new).and_wrap_original do |original, *args, **kwargs|
        original.call(*args, **kwargs).tap { |row| allow(row).to receive(:valid?).and_return(false) }
      end
      expect(Rails.logger).to receive(:warn).with(/Refusing to materialize .* fails validation/)

      expect(described_class.upsert(document)).to be_nil
    end

    # The draft requires registering redirect URIs only for grants that
    # redirect, so a document may omit redirect_uris entirely (say, a
    # client_credentials-only client). The row still materializes — with
    # nothing registered, the exact-match check closes the redirect-based
    # flows on its own — even though the server's grant flows would forbid
    # a registered application a blank redirect_uri.
    it "materializes a client whose document omits redirect_uris" do
      application = described_class.upsert(document("redirect_uris" => nil))

      expect(application).to be_persisted
      expect(application.redirect_uri).to be_blank
    end

    it "performs the write through the primary role" do
      # Rails routes the authorization endpoint's GET to a read replica when
      # automatic role switching is on, so the row must be written explicitly
      # against the primary.
      expect(Doorkeeper.config.application_model).to receive(:with_primary_role).and_call_original

      expect(described_class.upsert(document)).to be_persisted
    end

    # The Sequel extension's application mixin restricts mass assignment to
    # the user-editable columns (set_allowed_columns), so a uid passed to
    # +new+'s attribute hash would raise there; it must go through its writer.
    it "assigns the uid through its writer rather than new's attribute hash" do
      expect(Doorkeeper.config.application_model).to receive(:new).with(no_args).and_call_original

      expect(described_class.upsert(document).uid).to eq(url)
    end

    it "returns the winning row when a concurrent resolution raced on the uid" do
      existing = described_class.upsert(document)
      lose_race_with(ActiveRecord::RecordNotUnique.new("duplicate uid"))

      expect(described_class.upsert(document).id).to eq(existing.id)
    end

    # The same race is observable one step earlier: the model validates the
    # uid's uniqueness, so a row committed between the initial lookup and
    # valid?'s own SELECT fails validation instead of the insert. That
    # failure is a lost race, not a bad document, and recovers through the
    # same winner lookup.
    it "returns the winning row when the race is observed by the uniqueness validation" do
      winner = described_class.upsert(document)
      lookups = 0
      allow(Doorkeeper.config.application_model).to receive(:by_uid).and_wrap_original do |original, *args|
        (lookups += 1) == 1 ? nil : original.call(*args)
      end

      expect(described_class.upsert(document).id).to eq(winner.id)
    end

    # And one step later still: save validates again, so a row committed
    # between valid?'s SELECT and save's own fails that second validation
    # instead — save answers false, and no insert was ever attempted. Same
    # race, same recovery.
    it "returns the winning row when the race is observed by save's own validation" do
      winner = described_class.upsert(document)
      lookups = 0
      allow(Doorkeeper.config.application_model).to receive(:by_uid).and_wrap_original do |original, *args|
        (lookups += 1) == 1 ? nil : original.call(*args)
      end
      # The row validates once before save (the race is not yet visible) and
      # for real inside it.
      allow(Doorkeeper.config.application_model).to receive(:new).and_wrap_original do |original, *args, **kwargs|
        original.call(*args, **kwargs).tap do |row|
          validations = 0
          allow(row).to receive(:valid?).and_wrap_original do |validate, *validate_args|
            (validations += 1) == 1 || validate.call(*validate_args)
          end
        end
      end

      expect(described_class.upsert(document).id).to eq(winner.id)
    end

    # The row already exists, so a document that no longer validates must fail
    # the client and leave that row alone — never recover through race_winner,
    # which only a lost creation can have earned: handing the stale row back
    # would report success with the very metadata the model just refused.
    it "fails the client, and leaves the row alone, when a refreshed document is invalid" do
      existing = described_class.upsert(document)
      config_is_set(:force_ssl_in_redirect_uri, true)
      allow(Rails.logger).to receive(:warn)

      result = described_class.upsert(document("redirect_uris" => ["http://app.example.com/callback"]))

      expect(result).to be_nil
      expect(existing.reload.redirect_uri).to eq("https://app.example.com/callback")
    end

    # Resolution runs on unauthenticated traffic, and Sequel's #save writes
    # every column rather than only the ones that moved, so an unchanged
    # document must not reach #save at all.
    it "does not write the row again when the document has not changed" do
      existing = described_class.upsert(document)
      allow(Doorkeeper.config.application_model).to receive(:by_uid).and_wrap_original do |original, *args|
        original.call(*args)&.tap { |row| expect(row).not_to receive(:save) }
      end

      expect(described_class.upsert(document)&.id).to eq(existing.id)
    end

    # MySQL answers 1366 for a character the column's charset cannot hold (a
    # 4-byte emoji in a legacy `utf8` column). Rails leaves that a bare
    # StatementInvalid, which must refuse the client rather than 500 at the
    # unauthenticated authorization endpoint.
    it "fails the client when the column's charset rejects the document's value" do
      fail_save_with(
        ActiveRecord::StatementInvalid.new("Mysql2::Error: Incorrect string value: '\\xF0\\x9F\\x92\\x80' for column 'name'"),
      )

      expect(described_class.upsert(document("client_name" => "💀"))).to be_nil
    end

    # A unique index tripped while updating an existing row cannot be the
    # uid insert race — the row already holds the uid. It is a host-added
    # index (a unique name, say) that this document's values ran into, and
    # recovering through race_winner would report success with the very
    # metadata the database just refused.
    it "fails the client when an update trips a host-added unique index" do
      existing = described_class.upsert(document)
      allow(Doorkeeper.config.application_model).to receive(:by_uid).and_wrap_original do |original, *args|
        original.call(*args)&.tap do |row|
          allow(row).to receive(:save)
            .and_raise(ActiveRecord::RecordNotUnique.new("index_oauth_applications_on_name"))
        end
      end

      expect(described_class.upsert(document("client_name" => "Conflicting Name"))).to be_nil
      expect(existing.reload.name).to eq("Example App")
    end

    # The insert can lose not only to a concurrent resolution but to an
    # administrator registering the same uid by hand; that winner is a
    # registered application, and adopting it is the takeover the stamp
    # exists to prevent.
    it "refuses a race winner that is a registered application" do
      FactoryBot.create(:application, uid: url)
      lose_race_with(ActiveRecord::RecordNotUnique.new("duplicate uid"))

      expect(described_class.upsert(document)).to be_nil
    end

    # Each supported ORM extension reports the lost race in its own way;
    # recognizing only ActiveRecord's would turn the same survivable race
    # into a 500 under the others.
    it "returns the winning row when Sequel reports the raced unique index" do
      stub_const("Sequel::UniqueConstraintViolation", Class.new(StandardError))
      existing = described_class.upsert(document)
      lose_race_with(Sequel::UniqueConstraintViolation.new("duplicate key value violates unique constraint"))

      expect(described_class.upsert(document).id).to eq(existing.id)
    end

    # Sequel's save validates again and raises where ActiveRecord's answers
    # false, so the race observed by save's own validation arrives here as
    # an exception.
    it "returns the winning row when Sequel reports the race from save's own validation" do
      stub_const("Sequel::ValidationFailed", Class.new(StandardError))
      existing = described_class.upsert(document)
      lose_race_with(Sequel::ValidationFailed.new("uid is already taken"))

      expect(described_class.upsert(document).id).to eq(existing.id)
    end

    it "returns the winning row when the Mongo driver reports the duplicate key" do
      stub_const("Mongo::Error::OperationFailure", Class.new(StandardError))
      existing = described_class.upsert(document)
      lose_race_with(
        Mongo::Error::OperationFailure.new("E11000 duplicate key error collection: oauth_applications index: uid_1"),
      )

      expect(described_class.upsert(document).id).to eq(existing.id)
    end

    # The real driver reports a duplicate key as a numeric code; the message
    # is only the fallback for wrapped or legacy failures.
    [11_000, 11_001].each do |code|
      it "returns the winning row when the Mongo driver reports code #{code} alone" do
        stub_const("Mongo::Error::OperationFailure", Class.new(StandardError) { define_method(:code) { code } })
        existing = described_class.upsert(document)
        lose_race_with(Mongo::Error::OperationFailure.new("duplicate key error collection: oauth_applications"))

        expect(described_class.upsert(document).id).to eq(existing.id)
      end
    end

    it "does not disguise other Mongo operation failures as a lost race" do
      stub_const("Mongo::Error::OperationFailure", Class.new(StandardError))
      fail_save_with(Mongo::Error::OperationFailure.new("connection reset by peer"))

      expect { described_class.upsert(document) }.to raise_error(Mongo::Error::OperationFailure)
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
      # Stamped for the same reason as above: an unstamped winner is refused
      # by its provenance whatever its uid says.
      other = FactoryBot.create(
        :application,
        uid: url.upcase,
        client_id_metadata_materialized_at: Time.now.utc,
      )
      lose_race_with(ActiveRecord::RecordNotUnique.new("duplicate uid"))
      allow(Doorkeeper.config.application_model).to receive(:by_uid).with(url).and_return(nil, other)

      expect(described_class.upsert(document)).to be_nil
    end

    # An operator adopting a materialized row clears its stamp (the initializer
    # documents that as the way to keep such a client for good), and can do so
    # between the lookup that admits the row and the write that applies the
    # document to it. The stamp is unchanged in the object by then, so Active
    # Record would not write it back: the document's values would land on a
    # row nothing later refuses.
    it "refuses a row whose stamp is cleared while the document is being applied" do
      registered = FactoryBot.create(
        :application,
        uid: url,
        name: "Adopted by the operator",
        client_id_metadata_materialized_at: Time.now.utc,
      )
      allow(described_class).to receive(:invalid_row?).and_wrap_original do |original, application|
        Doorkeeper.config.application_model.where(id: registered.id)
          .update_all(client_id_metadata_materialized_at: nil)
        original.call(application)
      end

      expect(described_class.upsert(document)).to be_nil
      expect(registered.reload.name).to eq("Adopted by the operator")
    end

    # A lost race trips the unique index, and PostgreSQL then refuses every
    # later statement on a transaction the caller opened — including the read
    # that recovers the winner. The insert goes inside a savepoint so that
    # recovery is still possible there.
    it "confines the insert to a savepoint" do
      model = Doorkeeper.config.application_model
      expect(model).to receive(:transaction).with(requires_new: true).and_call_original

      expect(described_class.upsert(document)).to be_persisted
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
