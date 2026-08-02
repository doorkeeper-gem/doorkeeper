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

  # Enabling the option without running the migration leaves authentication
  # exactly as it was, which is silent — so the reason is said once, the first
  # time the columns are looked for. Looked for and not asked at boot: reading
  # them is a database read, and a boot hook would open a connection during
  # tasks that have none (assets:precompile and friends) to find that out.
  describe "the option set without the migration" do
    let(:model) do
      Class.new do
        extend Doorkeeper::ApplicationMixin::ClassMethods

        def self.name = "HostApp::OAuthApplication"

        def self.column_names = %w[id uid secret]
      end
    end

    before { enable_rotation }

    it "warns the first time the columns are looked for" do
      expect(Rails.logger).to receive(:warn).with(/enable_secret_rotation is set/).once

      expect(model.secret_rotation_enabled?).to be(false)
    end

    it "says it once per process rather than on every authentication" do
      expect(Rails.logger).to receive(:warn).with(/enable_secret_rotation is set/).once

      3.times { model.secret_rotation_enabled? }
    end

    it "stays quiet while the option is off" do
      Doorkeeper.configure { orm DOORKEEPER_ORM }

      expect(Rails.logger).not_to receive(:warn).with(/enable_secret_rotation is set/)

      expect(model.secret_rotation_enabled?).to be(false)
    end

    it "stays quiet once the migration has been run" do
      expect(Rails.logger).not_to receive(:warn).with(/enable_secret_rotation is set/)

      expect(Doorkeeper.config.application_model.secret_rotation_enabled?).to be(true)
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

      # The remedy the message names has to be one that ends a grace period.
      # #renew_secret writes the current secret alone, so on a row an earlier
      # rotation left an old_secret on it would leave that credential in
      # place — see the example below for what that comes to.
      it "points at the call that ends a grace period rather than at #renew_secret" do
        expect { app.rotate_secret! }
          .to raise_error(Doorkeeper::Errors::SecretRotationNotEnabled, /rotate_secret!\(revoke_old: true\)/)
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

        # A public client may store no secret at all (the column is nullable
        # in the generated schema). Restoring the row puts that nil back, and
        # nothing may then be compared against it: the strategies raise on a
        # nil stored value, which would mask the error the rotation raises.
        it "raises the write's own error for an application storing no secret" do
          public_app = FactoryBot.create(:application, confidential: false)
          public_app.update_column(:secret, nil)
          invalidate_stored_row(public_app)

          expect { public_app.rotate_secret! }.to raise_error(ActiveRecord::RecordInvalid)

          expect(public_app.secret).to be_nil
          expect(public_app.plaintext_secret).to be_nil
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

        # An application created before hashing was enabled stores its secret
        # plain, which is what `fallback: :plain` exists to keep serving. The
        # failed rotation restores that legacy value, so the plaintext still
        # describes what is stored — the restore check has to consult the
        # fallback strategy the way every other comparison does.
        it "puts the volatile plaintext of a legacy plain secret back under fallback: :plain" do
          fresh = FactoryBot.create(:application)
          plaintext = fresh.plaintext_secret

          Doorkeeper.configure do
            orm DOORKEEPER_ORM
            hash_application_secrets fallback: :plain
            enable_secret_rotation
          end
          invalidate_stored_row(fresh)

          expect { fresh.rotate_secret! }.to raise_error(ActiveRecord::RecordInvalid)

          expect(fresh.plaintext_secret).to eq(plaintext)
        end

        # Under Plain, #plaintext_secret reads the column and never looks at
        # @raw_secret, so the guard's post-condition is only observable under
        # a hashing strategy: there a guard answering `raw` would leave the
        # instance handing out a plaintext for a secret the row does not hold.
        it "drops the plaintext for an application storing no secret, under hashing" do
          Doorkeeper.configure do
            orm DOORKEEPER_ORM
            hash_application_secrets
            enable_secret_rotation
          end
          public_app = FactoryBot.create(:application, confidential: false)
          public_app.update_column(:secret, nil)
          invalidate_stored_row(public_app)

          expect { public_app.rotate_secret! }.to raise_error(ActiveRecord::RecordInvalid)

          expect(public_app.secret).to be_nil
          expect(public_app.plaintext_secret).to be_nil
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

        # A host `after_commit` callback raising reaches the rescue on the
        # other side of the commit: the rotation is already written, the
        # restore is a no-op, and the plaintext this rotation generated is
        # the only copy of the committed secret — it must survive the raise
        # rather than be swapped for the pre-rotation one (which no longer
        # matches anything stored).
        it "keeps the committed plaintext when a host after_commit callback raises" do
          Doorkeeper.configure do
            orm DOORKEEPER_ORM
            hash_application_secrets
            enable_secret_rotation
          end

          klass = build_application_model
          boom = false
          klass.after_commit { raise "boom" if boom }
          committed = klass.create!(FactoryBot.attributes_for(:application))
          boom = true

          expect { committed.rotate_secret! }.to raise_error(RuntimeError, "boom")

          boom = false
          stored = klass.find(committed.id)
          expect(stored.old_secret).to be_present
          expect(committed.plaintext_secret).to be_present
          expect(stored.secret_matches?(committed.plaintext_secret)).to be(true)
        end
      end

      # A failure landing after validation has `save!` stamp `updated_at`
      # before the UPDATE, and Active Record's rollback marks it dirty against
      # the pre-transaction snapshot. Restoring only the three secret columns
      # left it behind, and one dirty attribute is enough to make every later
      # `with_lock` on the instance raise — so neither API could be retried on
      # it, which is the opposite of what #revoke_issued_credentials!'s
      # documentation promises.
      context "when the failure lands after validation" do
        it "leaves the instance clean enough to retry" do
          enable_rotation
          klass = build_application_model
          boom = false
          klass.after_save { raise "boom" if boom }
          record = klass.create!(FactoryBot.attributes_for(:application))
          boom = true

          expect { record.rotate_secret! }.to raise_error(RuntimeError, "boom")
          expect(record.changed).to be_empty

          boom = false
          expect { record.rotate_secret! }.not_to raise_error
          expect { record.clear_old_secret! }.not_to raise_error
        end
      end

      # `with_lock` gates both of its guarantees on `persisted?`, so on a new
      # record it takes no row lock and does not refuse unsaved changes: the
      # rotation would INSERT whatever the caller had assigned and retain a
      # caller-supplied secret as `old_secret`, creating a row already midway
      # through a rotation nobody performed.
      context "when the record was never saved" do
        it "refuses to rotate" do
          enable_rotation
          record = Doorkeeper::Application.new(
            FactoryBot.attributes_for(:application).merge(secret: "known-secret"),
          )

          expect { record.rotate_secret! }.to raise_error(ActiveRecord::RecordNotSaved, /needs a persisted/)
          expect(record).not_to be_persisted
        end

        it "refuses to clear" do
          enable_rotation

          expect { Doorkeeper::Application.new.clear_old_secret! }
            .to raise_error(ActiveRecord::RecordNotSaved, /needs a persisted/)
        end
      end

      # A destroyed record is not persisted either, and saving it would not
      # bring it back, so it is not told to.
      context "when the record was destroyed" do
        it "says so rather than asking for a save" do
          enable_rotation
          app.destroy!

          expect { app.rotate_secret! }
            .to raise_error(ActiveRecord::RecordNotSaved, /needs a persisted.*has been destroyed/)
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

      # The plaintext is only filtered against the stored secret where the
      # rotation wrote something. A guard raising before the lock block wrote
      # nothing, so an unsaved `secret` the caller had assigned must not cost
      # them the plaintext of the secret the row still holds.
      it "keeps the volatile plaintext when the feature is off and a secret was assigned" do
        Doorkeeper.configure do
          orm DOORKEEPER_ORM
          hash_application_secrets
        end
        fresh = FactoryBot.create(:application)
        plaintext = fresh.plaintext_secret
        fresh.secret = "pending"

        expect { fresh.rotate_secret! }.to raise_error(Doorkeeper::Errors::SecretRotationNotEnabled)

        expect(fresh.plaintext_secret).to eq(plaintext)
      end

      it "keeps the volatile plaintext when the lock is refused and a secret was assigned" do
        Doorkeeper.configure do
          orm DOORKEEPER_ORM
          hash_application_secrets
          enable_secret_rotation
        end
        fresh = FactoryBot.create(:application)
        plaintext = fresh.plaintext_secret
        fresh.secret = "pending"

        expect { fresh.rotate_secret! }.to raise_error(RuntimeError, /unpersisted changes/)

        expect(fresh.plaintext_secret).to eq(plaintext)
      end

      # A host schema that relaxed the install migration's `null: false` can
      # hold an application with no secret. There is nothing to give a grace
      # period to, so the rotation must not open one.
      context "when there is no secret to retain" do
        let(:public_app) { FactoryBot.create(:application, confidential: false) }

        before { public_app.update_column(:secret, nil) }

        it "retains nothing and dates nothing" do
          public_app.rotate_secret!

          expect(public_app.reload.old_secret).to be_nil
          expect(public_app.old_secret_created_at).to be_nil
          expect(public_app.secret).to be_present
        end

        it "leaves no grace period for #clear_old_secret! to chase" do
          public_app.rotate_secret!

          expect(public_app.clear_old_secret!).to be(false)
          expect(public_app.reload.old_secret_created_at).to be_nil
        end
      end

      context "with revoke_old: true" do
        it "retains nothing" do
          previous = app.secret

          app.rotate_secret!(revoke_old: true)

          expect(app.reload.old_secret).to be_nil
          expect(app.old_secret_created_at).to be_nil
          expect(app.secret).not_to eq(previous)
        end

        # Discarding a secret an *earlier* rotation retained is covered by
        # "replacing a secret with no grace period" below, which also checks
        # that the discarded one stops authenticating.
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
    end
  end

  # What the docs point at for "replace the secret with no grace period at
  # all". #renew_secret is not that call once the feature is on: it writes the
  # current secret alone, so an old_secret an earlier rotation retained keeps
  # authenticating — indefinitely, with no deadline configured.
  # README: a rotation joined to a transaction that rolls back leaves the row
  # on the previous secret, the returned secret authenticating nothing, and
  # the instance carrying the undone rotation as unsaved changes until it is
  # reloaded — which is why the secret goes to the client only after the
  # commit.
  describe "#rotate_secret! inside a transaction that rolls back" do
    it "leaves the undone rotation as unsaved changes and the row on the previous secret" do
      enable_rotation
      stored = app.secret
      returned = nil

      Doorkeeper::Application.transaction do
        returned = app.rotate_secret!
        raise ActiveRecord::Rollback
      end

      expect(app.changed).to include("secret", "old_secret")
      reloaded = Doorkeeper::Application.find(app.id)
      expect(reloaded.secret).to eq(stored)
      expect(reloaded.secret_matches?(returned)).to be(false)
    end
  end

  describe "#clear_old_secret!" do
    context "when rotation is not available" do
      it "raises when the columns are missing" do
        enable_rotation
        allow(Doorkeeper::Application).to receive(:column_names)
          .and_return(Doorkeeper::Application.column_names - ["old_secret"])

        expect { app.clear_old_secret! }
          .to raise_error(Doorkeeper::Errors::SecretRotationNotEnabled)
      end

      # Gated on the columns and not on the option, unlike #rotate_secret!.
      # Turning `enable_secret_rotation` off stops a retained secret
      # authenticating but leaves it in the row, where it comes back into
      # service the moment the option does — so dropping it must not require
      # re-arming the feature for every application on the server first.
      it "still ends a grace period left behind by a server that turned the option off" do
        enable_rotation
        old_plaintext = app.plaintext_secret
        app.rotate_secret!

        Doorkeeper.configure { orm DOORKEEPER_ORM }
        expect(Doorkeeper::Application.secret_rotation_enabled?).to be(false)

        expect(app.clear_old_secret!).to be(true)
        expect(app.reload.old_secret).to be_nil
        expect(app.old_secret_created_at).to be_nil

        enable_rotation
        expect(app.secret_matches?(old_plaintext)).to be(false)
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

      # A timestamp with nothing behind it still says the application is
      # midway through a rotation, so clearing has something to do: a cleanup
      # job driven by `old_secret_created_at` would otherwise reselect the row
      # on every run without ever converging.
      it "clears a timestamp left behind with no old secret" do
        app.update_columns(old_secret: nil, old_secret_created_at: Time.now.utc)

        expect(app.clear_old_secret!).to be(true)
        expect(app.reload.old_secret_created_at).to be_nil
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

      # The mirror of the timestamp-with-no-secret row below: a retained
      # secret with no date. #old_secret_expired? singles that state out and,
      # with no deadline configured, keeps such a secret alive forever — so
      # clearing has to reach it.
      it "clears a retained secret left behind with no timestamp" do
        app.update_columns(old_secret: "undated", old_secret_created_at: nil)

        expect(app.clear_old_secret!).to be(true)
        expect(app.reload.old_secret).to be_nil
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

      # Taking the lock reloads the row, and under hashing the volatile
      # plaintext is the only copy of the secret this instance generated. A
      # rotation that ran since has superseded it — and this call is what
      # stops a superseded secret authenticating — so it must not stay behind
      # as this instance's answer for a secret the row no longer holds.
      it "drops a plaintext another rotation has superseded" do
        Doorkeeper.configure do
          orm DOORKEEPER_ORM
          hash_application_secrets
          enable_secret_rotation
        end
        fresh = FactoryBot.create(:application)
        plaintext = fresh.plaintext_secret
        Doorkeeper::Application.find(fresh.id).rotate_secret!

        expect(fresh.clear_old_secret!).to be(true)

        expect(fresh.plaintext_secret).to be_nil
        expect(fresh.secret_matches?(plaintext)).to be(false)
      end

      # The reload happens whether or not there is anything to clear, so the
      # plaintext is reconciled ahead of that decision rather than with the
      # write.
      it "drops it even when there was nothing left to clear" do
        Doorkeeper.configure do
          orm DOORKEEPER_ORM
          hash_application_secrets
          enable_secret_rotation
        end
        fresh = FactoryBot.create(:application)
        elsewhere = Doorkeeper::Application.find(fresh.id)
        elsewhere.rotate_secret!
        elsewhere.clear_old_secret!

        expect(fresh.clear_old_secret!).to be(false)

        expect(fresh.plaintext_secret).to be_nil
      end

      # The other direction: nothing raced this instance, so the plaintext it
      # holds is still the stored secret's and clearing a grace period is no
      # reason to take it away.
      it "keeps the plaintext that still describes the stored secret" do
        Doorkeeper.configure do
          orm DOORKEEPER_ORM
          hash_application_secrets
          enable_secret_rotation
        end
        fresh = FactoryBot.create(:application)
        plaintext = fresh.rotate_secret!

        expect(fresh.clear_old_secret!).to be(true)

        expect(fresh.plaintext_secret).to eq(plaintext)
        expect(fresh.secret_matches?(plaintext)).to be(true)
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

      # The validation failure below raises before the write; this one raises
      # after it. `update!` would snapshot the record while still clean, so
      # the rollback left it clean holding the cleared values — reporting a
      # grace period the row still has, and clean enough that a later `save`
      # writes nothing.
      context "when the failure lands after the write" do
        it "puts the retained secret back on the instance" do
          enable_rotation
          klass = build_application_model
          boom = false
          klass.after_save { raise "boom" if boom }
          record = klass.create!(FactoryBot.attributes_for(:application))
          record.rotate_secret!
          record.reload
          boom = true

          expect { record.clear_old_secret! }.to raise_error(RuntimeError, "boom")

          boom = false
          expect(record.old_secret).to be_present
          expect(record.old_secret).to eq(klass.find(record.id).old_secret)
          expect(record.changed).to be_empty
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
end
