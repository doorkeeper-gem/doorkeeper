# frozen_string_literal: true

require "spec_helper"
require "bcrypt"

# Client secret rotation (`enable_secret_rotation`): the secret superseded by
# `#rotate_secret!` keeps authenticating the client until the application ends
# the grace period with `#clear_old_secret!`.
RSpec.describe "client secret rotation" do
  let(:app) { FactoryBot.create(:application) }

  def enable_rotation
    Doorkeeper.configure do
      orm DOORKEEPER_ORM
      enable_secret_rotation
    end
  end

  describe "Doorkeeper.config#enable_secret_rotation?" do
    it "is disabled by default" do
      expect(Doorkeeper.config.enable_secret_rotation?).to be(false)
    end

    it "is enabled once the option is set" do
      enable_rotation

      expect(Doorkeeper.config.enable_secret_rotation?).to be(true)
    end
  end

  describe ".secret_rotation_enabled?" do
    it "is false while the option is off, even though the column exists" do
      expect(Doorkeeper::Application.column_names).to include("old_secret")
      expect(Doorkeeper::Application.secret_rotation_enabled?).to be(false)
    end

    it "is true with the option on and the column present" do
      enable_rotation

      expect(Doorkeeper::Application.secret_rotation_enabled?).to be(true)
    end

    # Enabling the option without running the migration must not raise on
    # every token request; it leaves authentication exactly as it was.
    it "is false with the option on but the column missing" do
      enable_rotation
      allow(Doorkeeper::Application).to receive(:column_names)
        .and_return(Doorkeeper::Application.column_names - ["old_secret"])

      expect(Doorkeeper::Application.secret_rotation_enabled?).to be(false)
    end

    # A rotation writes both columns, so half a migration is no more usable
    # than none: failing the check keeps it a no-op instead of a NoMethodError
    # on the first rotation.
    it "is false with the option on but the timestamp column missing" do
      enable_rotation
      allow(Doorkeeper::Application).to receive(:column_names)
        .and_return(Doorkeeper::Application.column_names - ["old_secret_created_at"])

      expect(Doorkeeper::Application.secret_rotation_enabled?).to be(false)
    end
  end

  describe "#rotate_secret!" do
    context "when rotation is not available" do
      it "raises rather than dropping the superseded secret" do
        expect { app.rotate_secret! }
          .to raise_error(Doorkeeper::Errors::SecretRotationNotEnabled, /enable_secret_rotation/)
      end

      it "raises when the column is missing" do
        enable_rotation
        allow(Doorkeeper::Application).to receive(:column_names)
          .and_return(Doorkeeper::Application.column_names - ["old_secret"])

        expect { app.rotate_secret! }
          .to raise_error(Doorkeeper::Errors::SecretRotationNotEnabled, /doorkeeper:secret_rotation/)
      end

      it "leaves the secret untouched when it raises" do
        expect { app.rotate_secret! }.to raise_error(Doorkeeper::Errors::SecretRotationNotEnabled)

        expect(app.reload.secret).to be_present
        expect(app.old_secret).to be_nil
      end

      # The guard raises before anything is written, so there is nothing to
      # restore — doing so anyway would discard a value the caller assigned.
      it "keeps a caller's pending secret when it raises" do
        app.secret = "pending"

        expect { app.rotate_secret! }.to raise_error(Doorkeeper::Errors::SecretRotationNotEnabled)

        expect(app.secret).to eq("pending")
      end
    end

    context "when rotation is enabled" do
      before { enable_rotation }

      it "retains the superseded secret and generates a new one" do
        previous = app.secret

        app.rotate_secret!

        expect(app.reload.old_secret).to eq(previous)
        expect(app.secret).not_to eq(previous)
      end

      it "persists the rotation" do
        previous = app.secret

        app.rotate_secret!

        reloaded = Doorkeeper::Application.find(app.id)
        expect(reloaded.old_secret).to eq(previous)
        expect(reloaded.secret).not_to eq(previous)
      end

      it "returns the new plain text secret" do
        returned = app.rotate_secret!

        expect(returned).to be_present
        expect(app.reload.secret_matches?(returned)).to be(true)
      end

      it "records when the grace period started" do
        now = Time.now.utc

        app.rotate_secret!

        expect(app.reload.old_secret_created_at).to be_within(5).of(now)
      end

      it "keeps only one generation, ending the first grace period early" do
        first = app.secret
        app.rotate_secret!
        second = app.secret

        app.rotate_secret!

        expect(app.reload.old_secret).to eq(second)
        expect(app.old_secret).not_to eq(first)
        expect(app.secret_matches?(first)).to be(false)
      end

      it "writes through the primary database role" do
        config_is_set(:enable_multiple_database_roles, true)
        expect(ActiveRecord::Base).to receive(:connected_to).with(role: :writing).and_yield

        app.rotate_secret!
      end

      # Two rotations racing on the same row: without the lock the later one
      # retains a stale `secret` and overwrites a secret the earlier one had
      # already handed to a client, which would then never authenticate.
      it "reads the row back under a lock so a concurrent rotation is not lost" do
        stale = Doorkeeper::Application.find(app.id)
        first_secret = app.rotate_secret!

        second_secret = stale.rotate_secret!

        reloaded = Doorkeeper::Application.find(app.id)
        expect(reloaded.secret_matches?(second_secret)).to be(true)
        expect(reloaded.old_secret_matches?(first_secret)).to be(true)
      end

      it "takes the lock" do
        expect(app).to receive(:with_lock).and_call_original

        app.rotate_secret!
      end

      context "when the write fails" do
        # Invalidated in the database rather than on the instance: the record
        # has to be free of unsaved changes for the lock to be taken at all
        # (pinned below). A row holding a scope that the server later stopped
        # configuring is how a stored application comes to fail validation in
        # practice.
        def invalidate_stored_row(record)
          record.update_column(:scopes, "never_configured")
          config_is_set(:enforce_configured_scopes, true)
        end

        before { invalidate_stored_row(app) }

        it "leaves the stored secret alone" do
          stored = app.secret

          expect { app.rotate_secret! }.to raise_error(ActiveRecord::RecordInvalid)

          expect(Doorkeeper::Application.find(app.id).secret).to eq(stored)
          expect(Doorkeeper::Application.find(app.id).old_secret).to be_nil
        end

        # An instance still holding a secret that was never stored is a trap
        # for any caller that rescues and carries on.
        it "puts the in-memory attributes back" do
          stored = app.secret

          expect { app.rotate_secret! }.to raise_error(ActiveRecord::RecordInvalid)

          expect(app.secret).to eq(stored)
          expect(app.old_secret).to be_nil
          expect(app.old_secret_created_at).to be_nil
        end

        it "puts the volatile plaintext back" do
          Doorkeeper.configure do
            orm DOORKEEPER_ORM
            hash_application_secrets
            enable_secret_rotation
          end
          fresh = FactoryBot.create(:application)
          plaintext = fresh.plaintext_secret
          invalidate_stored_row(fresh)

          expect { fresh.rotate_secret! }.to raise_error(ActiveRecord::RecordInvalid)

          expect(fresh.plaintext_secret).to eq(plaintext)
        end

        # Taking the lock reloads, so a rotation that raced this one has
        # already replaced the secret the pre-lock plaintext described. Putting
        # that plaintext back over the reloaded value would leave a rescuing
        # caller holding a secret the row no longer has.
        it "does not put a plaintext back over a secret another rotation stored" do
          Doorkeeper.configure do
            orm DOORKEEPER_ORM
            hash_application_secrets
            enable_secret_rotation
          end
          fresh = FactoryBot.create(:application)
          plaintext = fresh.plaintext_secret

          Doorkeeper::Application.find(fresh.id).rotate_secret!
          stored = Doorkeeper::Application.find(fresh.id).secret
          invalidate_stored_row(fresh)

          expect { fresh.rotate_secret! }.to raise_error(ActiveRecord::RecordInvalid)

          expect(fresh.plaintext_secret).not_to eq(plaintext)
          expect(fresh.plaintext_secret).to be_nil
          expect(Doorkeeper::Application.find(fresh.id).secret).to eq(stored)
        end
      end

      # Taking the lock reloads the row, which Active Record refuses to do
      # over unsaved changes rather than discard them silently. The rotation
      # therefore requires a clean record — and must not itself discard what
      # the caller had changed.
      context "when the record carries unsaved changes" do
        before { app.name = "renamed but not saved" }

        it "refuses to rotate" do
          expect { app.rotate_secret! }.to raise_error(RuntimeError, /unpersisted changes/)
        end

        it "keeps the caller's own changes" do
          expect { app.rotate_secret! }.to raise_error(RuntimeError)

          expect(app.name).to eq("renamed but not saved")
        end

        # Even when the change is to a column a rotation would restore: the
        # lock was refused, so the rotation never wrote anything.
        it "keeps the caller's value on the rotation columns" do
          app.secret = "pending"

          expect { app.rotate_secret! }.to raise_error(RuntimeError)

          expect(app.secret).to eq("pending")
        end
      end

      # The guard raises before anything is attempted, so it must not cost the
      # caller the plaintext of the secret the application already has.
      it "keeps the volatile plaintext when the guard raises" do
        Doorkeeper.configure do
          orm DOORKEEPER_ORM
          hash_application_secrets
        end
        fresh = FactoryBot.create(:application)
        plaintext = fresh.plaintext_secret

        expect { fresh.rotate_secret! }.to raise_error(Doorkeeper::Errors::SecretRotationNotEnabled)

        expect(fresh.plaintext_secret).to eq(plaintext)
      end

      context "with revoke_old: true" do
        it "retains nothing" do
          previous = app.secret

          app.rotate_secret!(revoke_old: true)

          expect(app.reload.old_secret).to be_nil
          expect(app.old_secret_created_at).to be_nil
          expect(app.secret).not_to eq(previous)
        end

        it "discards a secret retained by an earlier rotation" do
          app.rotate_secret!
          expect(app.reload.old_secret).to be_present

          app.rotate_secret!(revoke_old: true)

          expect(app.reload.old_secret).to be_nil
        end
      end

      context "with revoke_tokens: true" do
        let!(:token) { FactoryBot.create(:access_token, application: app) }
        let!(:grant) { FactoryBot.create(:access_grant, application: app) }

        it "revokes the access tokens already issued" do
          app.rotate_secret!(revoke_old: true, revoke_tokens: true)

          expect(token.reload).to be_revoked
        end

        # An unredeemed authorization code is exchanged with the client
        # secret, so leaving it alive would hand out a token minted after the
        # revocation.
        it "revokes the unredeemed authorization codes" do
          app.rotate_secret!(revoke_old: true, revoke_tokens: true)

          expect(grant.reload).to be_revoked
        end

        it "leaves an already revoked token's revoked_at alone" do
          token.revoke
          revoked_at = token.reload.revoked_at

          app.rotate_secret!(revoke_old: true, revoke_tokens: true)

          expect(token.reload.revoked_at).to eq(revoked_at)
        end

        it "does not touch another application's tokens" do
          other = FactoryBot.create(:access_token)

          app.rotate_secret!(revoke_old: true, revoke_tokens: true)

          expect(other.reload).not_to be_revoked
        end

        it "revokes nothing unless asked" do
          app.rotate_secret!

          expect(token.reload).not_to be_revoked
          expect(grant.reload).not_to be_revoked
        end

        # A token request locks its grant or refresh token and then inserts a
        # token, which share-locks the application row for the foreign key
        # check. Revoking the child rows while the rotation still holds
        # `FOR UPDATE` on the application reverses that order and the two
        # deadlock, so the sweep has to wait for the lock to be released.
        it "revokes only after the rotation has been committed" do
          connection = app.class.connection
          depth_outside = connection.open_transactions
          depth_during_sweep = nil

          allow(app).to receive(:revoke_issued_credentials!).and_wrap_original do |m, *args|
            depth_during_sweep = connection.open_transactions
            m.call(*args)
          end

          app.rotate_secret!(revoke_old: true, revoke_tokens: true)

          expect(depth_during_sweep).to eq(depth_outside)
          expect(token.reload).to be_revoked
        end

        # The rotation is already stored by the time the sweep runs, so a
        # failure there must not leave the instance describing the old secret.
        it "keeps the committed rotation when the revocation fails" do
          allow(app).to receive(:revoke_issued_credentials!).and_raise(ActiveRecord::StatementInvalid)
          stored = app.secret

          expect do
            app.rotate_secret!(revoke_old: true, revoke_tokens: true)
          end.to raise_error(ActiveRecord::StatementInvalid)

          expect(Doorkeeper::Application.find(app.id).secret).not_to eq(stored)
          expect(app.secret).to eq(Doorkeeper::Application.find(app.id).secret)
          expect(app.secret_matches?(app.plaintext_secret)).to be(true)
          expect(token.reload).not_to be_revoked
        end

        # The plaintext only ever leaves through the return value, which a
        # raise skips — so it has to stay readable on the instance, and the
        # sweep has to be retryable on its own.
        it "keeps the new plaintext readable and lets the revocation be retried" do
          calls = 0
          allow(app).to receive(:revoke_issued_credentials!).and_wrap_original do |m, *args|
            calls += 1
            raise ActiveRecord::StatementInvalid if calls == 1

            m.call(*args)
          end

          expect do
            app.rotate_secret!(revoke_old: true, revoke_tokens: true)
          end.to raise_error(ActiveRecord::StatementInvalid)

          plaintext = app.plaintext_secret
          expect(Doorkeeper::Application.find(app.id).secret_matches?(plaintext)).to be(true)

          app.revoke_issued_credentials!

          expect(token.reload).to be_revoked
          expect(grant.reload).to be_revoked
        end
      end
    end

    context "with hashed application secrets" do
      include_context "with application hashing enabled"

      before { enable_secret_rotation_on_top_of_hashing }

      # `hash_application_secrets` and `enable_secret_rotation` are set in
      # separate `Doorkeeper.configure` calls in these specs, and each call
      # replaces the configuration wholesale, so the second one has to restate
      # the first.
      def enable_secret_rotation_on_top_of_hashing
        Doorkeeper.configure do
          orm DOORKEEPER_ORM
          hash_application_secrets
          enable_secret_rotation
        end
      end

      it "carries the stored secret over verbatim rather than re-deriving it" do
        stored = app.secret

        app.rotate_secret!

        expect(app.reload.old_secret).to eq(stored)
      end

      it "keeps both secrets usable through the hashing strategy" do
        old_plaintext = app.plaintext_secret

        new_plaintext = app.rotate_secret!

        expect(app.reload.secret_matches?(old_plaintext)).to be(true)
        expect(app.secret_matches?(new_plaintext)).to be(true)
      end
    end

    context "with bcrypt application secrets" do
      before do
        Doorkeeper.configure do
          orm DOORKEEPER_ORM
          hash_application_secrets using: "Doorkeeper::SecretStoring::BCrypt"
          enable_secret_rotation
        end
      end

      # bcrypt draws a fresh salt on every write, so the old secret can only
      # be retained by copying the stored digest — there is no plaintext left
      # to hash again.
      it "keeps the retained digest verifiable" do
        old_plaintext = app.plaintext_secret
        stored = app.secret

        app.rotate_secret!

        expect(app.reload.old_secret).to eq(stored)
        expect(app.secret_matches?(old_plaintext)).to be(true)
      end
    end
  end

  # `with_lock` joins an open transaction, and the row lock then outlives
  # the method — past the point the revocation runs, recreating the lock
  # order inversion it is kept out of the lock to avoid.
  describe "#rotate_secret!(revoke_tokens: true) inside a transaction" do
    before { enable_rotation }

    let!(:token) { FactoryBot.create(:access_token, application: app) }

    it "is refused before anything is written" do
      stored = app.secret
      plaintext = app.plaintext_secret

      expect do
        Doorkeeper::Application.transaction do
          app.rotate_secret!(revoke_old: true, revoke_tokens: true)
        end
      end.to raise_error(Doorkeeper::Errors::SecretRotationInTransaction, /revoke_issued_credentials!/)

      expect(Doorkeeper::Application.find(app.id).secret).to eq(stored)
      expect(app.secret).to eq(stored)
      expect(app.plaintext_secret).to eq(plaintext)
      expect(app).not_to be_changed
      expect(token.reload).not_to be_revoked
    end

    it "lets the caller rotate and revoke around their commit instead" do
      stored = app.secret

      Doorkeeper::Application.transaction do
        app.rotate_secret!(revoke_old: true)
      end
      app.revoke_issued_credentials!

      expect(Doorkeeper::Application.find(app.id).secret).not_to eq(stored)
      expect(token.reload).to be_revoked
    end

    it "is not refused by a transaction the rotation does not join" do
      Doorkeeper::Application.transaction(joinable: false) do
        app.rotate_secret!(revoke_old: true, revoke_tokens: true)
      end

      expect(token.reload).to be_revoked
    end
  end

  describe "#revoke_issued_credentials!" do
    before { enable_rotation }

    let!(:token) { FactoryBot.create(:access_token, application: app) }
    let!(:grant) { FactoryBot.create(:access_grant, application: app) }

    it "revokes the tokens and grants without touching the secret" do
      stored = app.secret

      app.revoke_issued_credentials!

      expect(token.reload).to be_revoked
      expect(grant.reload).to be_revoked
      expect(app.reload.secret).to eq(stored)
    end

    it "is idempotent" do
      app.revoke_issued_credentials!
      revoked_at = token.reload.revoked_at

      app.revoke_issued_credentials!

      expect(token.reload.revoked_at).to eq(revoked_at)
    end
  end

  describe "#clear_old_secret!" do
    context "when rotation is not available" do
      it "raises" do
        expect { app.clear_old_secret! }
          .to raise_error(Doorkeeper::Errors::SecretRotationNotEnabled)
      end
    end

    context "when rotation is enabled" do
      before { enable_rotation }

      it "ends the grace period" do
        old_plaintext = app.plaintext_secret
        app.rotate_secret!

        expect(app.clear_old_secret!).to be(true)

        expect(app.reload.old_secret).to be_nil
        expect(app.old_secret_created_at).to be_nil
        expect(app.secret_matches?(old_plaintext)).to be(false)
      end

      it "leaves the current secret alone" do
        new_plaintext = app.rotate_secret!

        app.clear_old_secret!

        expect(app.reload.secret_matches?(new_plaintext)).to be(true)
      end

      it "reports that there was nothing to clear" do
        expect(app.clear_old_secret!).to be(false)
      end

      it "writes through the primary database role" do
        app.rotate_secret!
        config_is_set(:enable_multiple_database_roles, true)
        expect(ActiveRecord::Base).to receive(:connected_to).with(role: :writing).and_yield

        app.clear_old_secret!
      end

      it "takes the lock" do
        app.rotate_secret!

        expect(app).to receive(:with_lock).and_call_original

        app.clear_old_secret!
      end

      # Read outside the lock, "is there anything to clear?" describes whatever
      # this instance was loaded with, which a rotation committed since then
      # has already made wrong.
      it "clears a rotation this instance had not seen" do
        stale = Doorkeeper::Application.find(app.id)
        old_plaintext = app.plaintext_secret
        app.rotate_secret!

        expect(stale.clear_old_secret!).to be(true)

        expect(app.reload.old_secret).to be_nil
        expect(app.secret_matches?(old_plaintext)).to be(false)
      end

      it "reports nothing to clear when another process got there first" do
        app.rotate_secret!
        stale = Doorkeeper::Application.find(app.id)
        app.clear_old_secret!

        expect(stale.clear_old_secret!).to be(false)
      end

      # Symmetric with #rotate_secret!: taking the lock reloads the row, which
      # Active Record refuses to do over unsaved changes.
      context "when the record carries unsaved changes" do
        before do
          app.rotate_secret!
          app.name = "renamed but not saved"
        end

        it "refuses to clear" do
          expect { app.clear_old_secret! }.to raise_error(RuntimeError, /unpersisted changes/)
        end

        it "keeps the caller's own changes" do
          expect { app.clear_old_secret! }.to raise_error(RuntimeError)

          expect(app.name).to eq("renamed but not saved")
        end

        # Symmetric with #rotate_secret!: the lock was refused, so nothing
        # was written and the restored columns must be left alone too.
        it "keeps the caller's value on the cleared columns" do
          app.old_secret = "caller-assigned"

          expect { app.clear_old_secret! }.to raise_error(RuntimeError)

          expect(app.old_secret).to eq("caller-assigned")
        end

        it "leaves the grace period open" do
          expect { app.clear_old_secret! }.to raise_error(RuntimeError)

          expect(app.reload.old_secret).to be_present
        end
      end

      context "when the write fails" do
        before do
          app.rotate_secret!
          app.update_column(:scopes, "never_configured")
          config_is_set(:enforce_configured_scopes, true)
        end

        it "leaves the grace period open in the database" do
          expect { app.clear_old_secret! }.to raise_error(ActiveRecord::RecordInvalid)

          expect(Doorkeeper::Application.find(app.id).old_secret).to be_present
        end

        # An instance claiming a grace period it no longer has is the same
        # trap #rotate_secret! avoids.
        it "puts the in-memory attributes back" do
          expect { app.clear_old_secret! }.to raise_error(ActiveRecord::RecordInvalid)

          expect(app.old_secret).to be_present
          expect(app.old_secret_created_at).to be_present
        end
      end
    end
  end

  describe "#old_secret_matches?" do
    it "is false while rotation is disabled, even with an old secret stored" do
      app.update_column(:old_secret, "retained")

      expect(app.old_secret_matches?("retained")).to be(false)
    end

    context "when rotation is enabled" do
      before { enable_rotation }

      it "is false when nothing has been rotated" do
        expect(app.old_secret_matches?(app.plaintext_secret)).to be(false)
      end

      it "is true for the secret the last rotation superseded" do
        old_plaintext = app.plaintext_secret
        app.rotate_secret!

        expect(app.old_secret_matches?(old_plaintext)).to be(true)
      end

      it "is false for the current secret" do
        new_plaintext = app.rotate_secret!

        expect(app.old_secret_matches?(new_plaintext)).to be(false)
      end

      it "is false for a nil input" do
        app.rotate_secret!

        expect(app.old_secret_matches?(nil)).to be(false)
      end

      it "is false for an application with no secret at all" do
        public_app = FactoryBot.create(:application, confidential: false)
        public_app.update_column(:secret, nil)

        expect(public_app.old_secret_matches?("anything")).to be(false)
      end
    end
  end

  describe "#secret_matches?" do
    context "when rotation is disabled" do
      # The feature costs nothing when it is off: the comparison is the same
      # single comparison it has always been.
      it "compares the current secret only" do
        app.update_column(:old_secret, "retained")

        expect(app).not_to receive(:old_secret_matches?)
        expect(app.secret_matches?(app.plaintext_secret)).to be(true)
        expect(app.secret_matches?("retained")).to be(false)
      end
    end

    context "when rotation is enabled" do
      before { enable_rotation }

      it "accepts the current secret" do
        new_plaintext = app.rotate_secret!

        expect(app.secret_matches?(new_plaintext)).to be(true)
      end

      it "accepts the superseded secret" do
        old_plaintext = app.plaintext_secret
        app.rotate_secret!

        expect(app.secret_matches?(old_plaintext)).to be(true)
      end

      it "rejects an unrelated secret" do
        app.rotate_secret!

        expect(app.secret_matches?("nope")).to be(false)
      end

      it "rejects a nil secret" do
        app.rotate_secret!

        expect(app.secret_matches?(nil)).to be(false)
      end

      it "stops accepting the superseded secret once the grace period ends" do
        old_plaintext = app.plaintext_secret
        app.rotate_secret!
        app.clear_old_secret!

        expect(app.secret_matches?(old_plaintext)).to be(false)
      end

      # Whether this client is midway through a rotation must not be readable
      # from how much work the comparison did, so a comparison runs either
      # way — against the current secret when there is no old one to check.
      it "compares twice even when nothing has been rotated" do
        expect(Doorkeeper::SecretStoring::Plain)
          .to receive(:secret_matches?).twice.and_call_original

        app.secret_matches?("nope")
      end

      it "compares twice when an old secret is stored" do
        app.rotate_secret!

        expect(Doorkeeper::SecretStoring::Plain)
          .to receive(:secret_matches?).twice.and_call_original

        app.secret_matches?("nope")
      end

      it "compares twice even when the current secret already matched" do
        new_plaintext = app.rotate_secret!

        expect(Doorkeeper::SecretStoring::Plain)
          .to receive(:secret_matches?).twice.and_call_original

        expect(app.secret_matches?(new_plaintext)).to be(true)
      end

      # The dummy comparison is made against a real stored secret, so under
      # bcrypt it costs the same work factor a genuine one would.
      it "performs the dummy comparison against a stored secret" do
        expect(Doorkeeper::SecretStoring::Plain)
          .to receive(:secret_matches?).with("nope", app.secret).twice.and_call_original

        app.secret_matches?("nope")
      end
    end

    context "with the fallback strategy and rotation enabled" do
      let(:plain_old_secret) { "plain text old secret" }

      before do
        Doorkeeper.configure do
          orm DOORKEEPER_ORM
          hash_application_secrets fallback: :plain
          enable_secret_rotation
        end

        # An application rotated while its secrets were still stored in plain
        # text: the retained value is in the fallback format.
        app.update_columns(old_secret: plain_old_secret, old_secret_created_at: Time.now.utc)
      end

      it "matches an old secret stored in the fallback format" do
        expect(app.secret_matches?(plain_old_secret)).to be(true)
      end

      it "upgrades the old secret to the active strategy on a match" do
        expect(Doorkeeper::Application).to receive(:upgrade_fallback_value).and_call_original

        expect(app.secret_matches?(plain_old_secret)).to be(true)

        expect(app.reload.old_secret)
          .to eq(Doorkeeper::SecretStoring::Sha256Hash.transform_secret(plain_old_secret))
      end

      it "still matches the old secret after the upgrade" do
        app.secret_matches?(plain_old_secret)

        expect(app.reload.secret_matches?(plain_old_secret)).to be(true)
      end
    end
  end

  describe ".by_uid_and_secret" do
    before { enable_rotation }

    it "finds the application by its superseded secret" do
      old_plaintext = app.plaintext_secret
      app.rotate_secret!

      expect(Doorkeeper::Application.by_uid_and_secret(app.uid, old_plaintext)).to eq(app)
    end

    it "finds the application by its current secret" do
      new_plaintext = app.rotate_secret!

      expect(Doorkeeper::Application.by_uid_and_secret(app.uid, new_plaintext)).to eq(app)
    end

    it "does not find it by a cleared secret" do
      old_plaintext = app.plaintext_secret
      app.rotate_secret!
      app.clear_old_secret!

      expect(Doorkeeper::Application.by_uid_and_secret(app.uid, old_plaintext)).to be_nil
    end
  end

  describe "after_old_secret_used" do
    let(:reported) { [] }

    before do
      hook = ->(application) { reported << application }

      Doorkeeper.configure do
        orm DOORKEEPER_ORM
        enable_secret_rotation
        after_old_secret_used hook
      end
    end

    it "reports the client that authenticated with the superseded secret" do
      old_plaintext = app.plaintext_secret
      app.rotate_secret!

      app.secret_matches?(old_plaintext)

      expect(reported).to eq([app])
    end

    it "stays quiet when the client has moved to the new secret" do
      new_plaintext = app.rotate_secret!

      app.secret_matches?(new_plaintext)

      expect(reported).to be_empty
    end

    it "stays quiet for a secret that matches neither" do
      app.rotate_secret!

      app.secret_matches?("nope")

      expect(reported).to be_empty
    end

    it "stays quiet once the grace period has been ended" do
      old_plaintext = app.plaintext_secret
      app.rotate_secret!
      app.clear_old_secret!

      app.secret_matches?(old_plaintext)

      expect(reported).to be_empty
    end

    it "fires through the full lookup path" do
      old_plaintext = app.plaintext_secret
      app.rotate_secret!

      Doorkeeper::Application.by_uid_and_secret(app.uid, old_plaintext)

      expect(reported).to eq([app])
    end

    it "is a no-op by default" do
      expect(Doorkeeper::Config.new.after_old_secret_used.call(app)).to be_nil
    end
  end

  describe "secret_rotation_grace_period" do
    let(:old_plaintext) { app.plaintext_secret }

    def enable_rotation_with_grace_period(period)
      Doorkeeper.configure do
        orm DOORKEEPER_ORM
        enable_secret_rotation
        secret_rotation_grace_period period
      end
    end

    it "is unset by default, so an old secret never expires on its own" do
      expect(Doorkeeper.config.secret_rotation_grace_period).to be_nil

      enable_rotation
      old_plaintext
      app.rotate_secret!
      app.update_column(:old_secret_created_at, 10.years.ago)

      expect(app.old_secret_expired?).to be(false)
      expect(app.secret_matches?(old_plaintext)).to be(true)
    end

    it "keeps accepting the old secret inside the grace period" do
      enable_rotation_with_grace_period(7 * 24 * 60 * 60)
      old_plaintext
      app.rotate_secret!
      app.update_column(:old_secret_created_at, 6.days.ago)

      expect(app.old_secret_expired?).to be(false)
      expect(app.secret_matches?(old_plaintext)).to be(true)
    end

    it "stops accepting it past the grace period" do
      enable_rotation_with_grace_period(7 * 24 * 60 * 60)
      old_plaintext
      app.rotate_secret!
      app.update_column(:old_secret_created_at, 8.days.ago)

      expect(app.old_secret_expired?).to be(true)
      expect(app.secret_matches?(old_plaintext)).to be(false)
    end

    it "leaves the current secret unaffected" do
      enable_rotation_with_grace_period(7 * 24 * 60 * 60)
      new_plaintext = app.rotate_secret!
      app.update_column(:old_secret_created_at, 8.days.ago)

      expect(app.secret_matches?(new_plaintext)).to be(true)
    end

    # Expiry stops the old secret authenticating; removing it is a separate
    # decision, so that an operator can still see that a rotation happened.
    it "does not remove the expired secret" do
      enable_rotation_with_grace_period(7 * 24 * 60 * 60)
      old_plaintext
      app.rotate_secret!
      app.update_column(:old_secret_created_at, 8.days.ago)

      app.secret_matches?(old_plaintext)

      expect(app.reload.old_secret).to be_present
    end

    # A deadline nobody can date would leave exactly the indefinitely-valid
    # secret the option was configured to prevent.
    it "treats an undated old secret as expired" do
      enable_rotation_with_grace_period(7 * 24 * 60 * 60)
      old_plaintext
      app.rotate_secret!
      app.update_column(:old_secret_created_at, nil)

      expect(app.old_secret_expired?).to be(true)
      expect(app.secret_matches?(old_plaintext)).to be(false)
    end

    # An undated *retained* secret is expired; an application that never
    # rotated has nothing retained, and so no grace period to outlive.
    it "reports an application that never rotated as not expired" do
      enable_rotation_with_grace_period(7 * 24 * 60 * 60)

      expect(app.old_secret).to be_nil
      expect(app.old_secret_expired?).to be(false)
    end

    it "reports nothing as expired while rotation is disabled" do
      Doorkeeper.configure do
        orm DOORKEEPER_ORM
        secret_rotation_grace_period 7 * 24 * 60 * 60
      end
      app.update_columns(old_secret: "retained", old_secret_created_at: 8.days.ago)

      # Asked directly as well: a value left in the column by a rotation that
      # ran before the option was turned off is not this feature's business
      # while the feature is off.
      expect(app.old_secret_expired?).to be(false)
      expect(app.secret_matches?(app.plaintext_secret)).to be(true)
    end

    # Same guard as `#old_secret_matches?`, so the public predicate answers
    # instead of raising on the `old_secret` a missing migration never added.
    it "reports nothing as expired with the option on but the column missing" do
      enable_rotation_with_grace_period(7 * 24 * 60 * 60)
      app.update_columns(old_secret: "retained", old_secret_created_at: 8.days.ago)
      allow(Doorkeeper::Application).to receive(:column_names)
        .and_return(Doorkeeper::Application.column_names - ["old_secret"])

      expect(app.old_secret_expired?).to be(false)
    end

    # Expiry is decided after the comparison has run, so it cannot shorten the
    # work an expired old secret costs.
    it "still compares twice for an expired old secret" do
      enable_rotation_with_grace_period(7 * 24 * 60 * 60)
      app.rotate_secret!
      app.update_column(:old_secret_created_at, 8.days.ago)

      expect(Doorkeeper::SecretStoring::Plain)
        .to receive(:secret_matches?).twice.and_call_original

      app.secret_matches?("nope")
    end
  end

  # The retained secret authenticates the client exactly as `secret` does, so
  # it is withheld from every serialization — including the owner view, which
  # otherwise dumps every attribute.
  describe "serialization" do
    before do
      enable_rotation
      app.rotate_secret!
    end

    it "does not expose the retained secret to the public" do
      expect(app.as_json.keys).not_to include("old_secret", "old_secret_created_at")
    end

    it "does not expose it to the owner either" do
      expect(app.as_json(as_owner: true).keys).not_to include("old_secret", "old_secret_created_at")
    end

    it "still gives the owner the attributes they came for" do
      json = app.as_json(as_owner: true)

      expect(json.keys).to include("id", "name", "uid", "secret", "scopes")
    end

    # The other half of the owner branch. `enable_application_owner` is a
    # load-time switch (#1831), so the owner association only exists on a
    # model class defined after it was turned on.
    it "does not expose it to a matching current_resource_owner" do
      owner = FactoryBot.create(:doorkeeper_testing_user)
      Doorkeeper.configure do
        orm DOORKEEPER_ORM
        enable_application_owner confirmation: false
        enable_secret_rotation
      end

      owned = build_application_model.new(FactoryBot.attributes_for(:application))
      owned.owner = owner
      owned.save!
      owned.rotate_secret!

      json = owned.as_json(current_resource_owner: owner)

      expect(json.keys).to include("secret", "redirect_uri")
      expect(json.keys).not_to include("old_secret", "old_secret_created_at")
    end

    # ActiveModel honours `only` or `except` but never both, so an exclusion
    # written only as `except` would be skipped whenever `only` is given.
    it "withholds it even when asked for by name" do
      json = app.as_json(as_owner: true, only: %i[id old_secret old_secret_created_at])

      expect(json.keys).to eq(["id"])
    end

    it "withholds it when asked for by name alone" do
      expect(app.as_json(as_owner: true, only: [:old_secret])).to eq({})
    end

    it "keeps an explicit except of the caller's own" do
      json = app.as_json(as_owner: true, except: [:scopes])

      expect(json.keys).not_to include("scopes", "old_secret", "old_secret_created_at")
      expect(json.keys).to include("secret")
    end

    it "does not mutate the options it was given" do
      options = { as_owner: true }

      app.as_json(options)

      expect(options).to eq({ as_owner: true })
    end
  end
end
