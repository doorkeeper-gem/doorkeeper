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

  # The grace period is consumed as `old_secret_created_at + grace_period`,
  # so a value that cannot be added to a time would boot fine and start
  # raising TypeError on the first client authentication after a rotation.
  # It is refused at configuration time instead.
  describe "Doorkeeper.config#secret_rotation_grace_period" do
    it "accepts a duration" do
      Doorkeeper.configure do
        orm DOORKEEPER_ORM
        enable_secret_rotation
        secret_rotation_grace_period 7.days
      end

      expect(Doorkeeper.config.secret_rotation_grace_period).to eq(7.days)
    end

    it "accepts a number of seconds" do
      Doorkeeper.configure do
        orm DOORKEEPER_ORM
        enable_secret_rotation
        secret_rotation_grace_period 3600
      end

      expect(Doorkeeper.config.secret_rotation_grace_period).to eq(3600)
    end

    it "refuses a value that cannot be added to a time" do
      expect do
        Doorkeeper.configure do
          orm DOORKEEPER_ORM
          enable_secret_rotation
          secret_rotation_grace_period "7 days"
        end
      end.to raise_error(ArgumentError, /secret_rotation_grace_period.*"7 days"/)
    end

    it "refuses a deadline that is never in the future" do
      [0, -1.day].each do |period|
        expect do
          Doorkeeper.configure do
            orm DOORKEEPER_ORM
            enable_secret_rotation
            secret_rotation_grace_period period
          end
        end.to raise_error(ArgumentError, /secret_rotation_grace_period/)
      end
    end

    # A positive Numeric that still cannot be added to a time — an endless
    # grace period is what the nil default already says.
    it "refuses an infinite grace period" do
      expect do
        Doorkeeper.configure do
          orm DOORKEEPER_ORM
          enable_secret_rotation
          secret_rotation_grace_period Float::INFINITY
        end
      end.to raise_error(ArgumentError, /secret_rotation_grace_period/)
    end

    # Complex is a Numeric too, one with no ordering: asking whether it is
    # positive raises rather than answers, so it is sorted out before that.
    it "refuses a complex number" do
      expect do
        Doorkeeper.configure do
          orm DOORKEEPER_ORM
          enable_secret_rotation
          secret_rotation_grace_period Complex(1, 0)
        end
      end.to raise_error(ArgumentError, /secret_rotation_grace_period/)
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

      # Why the message says what it says: turning the option off stops the
      # retained secret authenticating but does not remove it, and #renew_secret
      # does not either — so it is live again as soon as rotation is available.
      it "leaves a retained secret to authenticate again once rotation returns" do
        enable_rotation
        old_plaintext = app.plaintext_secret
        app.rotate_secret!
        Doorkeeper.configure { orm DOORKEEPER_ORM }

        expect(app.reload.secret_matches?(old_plaintext)).to be(false)

        app.renew_secret
        app.save!
        enable_rotation

        expect(app.reload.read_attribute(:old_secret)).to be_present
        expect(app.secret_matches?(old_plaintext)).to be(true)
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

  describe "replacing a secret with no grace period" do
    before { enable_rotation }

    it "is #rotate_secret!(revoke_old: true), which drops what was retained" do
      first = app.plaintext_secret
      app.rotate_secret!

      app.rotate_secret!(revoke_old: true)

      expect(app.reload.old_secret).to be_nil
      expect(app.secret_matches?(first)).to be(false)
    end

    it "is not #renew_secret, which leaves an open grace period open" do
      first = app.plaintext_secret
      app.rotate_secret!

      app.renew_secret
      app.save!

      expect(app.reload.old_secret).to be_present
      expect(app.secret_matches?(first)).to be(true)
    end
  end

  # A job selecting rows by an expired old_secret_created_at is the pattern the
  # README points at, and it reads that column before it takes the lock — a
  # rotation committing in between would otherwise have the job end a grace
  # period that had just been opened.
  describe "#clear_old_secret!(retained_at:)" do
    before { enable_rotation }

    it "clears the grace period the caller decided on" do
      app.rotate_secret!
      observed = app.reload.old_secret_created_at

      expect(app.clear_old_secret!(retained_at: observed)).to be(true)
      expect(app.reload.old_secret).to be_nil
    end

    it "leaves a grace period opened since the caller looked" do
      app.rotate_secret!
      observed = app.reload.old_secret_created_at
      # The race: another rotation commits between the caller's query and its
      # call, retaining a secret of its own.
      Doorkeeper::Application.find(app.id).rotate_secret!
      retained = Doorkeeper::Application.find(app.id).old_secret

      expect(app.clear_old_secret!(retained_at: observed)).to be(false)
      expect(Doorkeeper::Application.find(app.id).old_secret).to eq(retained)
    end

    it "clears whatever is there when no timestamp is named" do
      app.rotate_secret!
      Doorkeeper::Application.find(app.id).rotate_secret!

      expect(app.clear_old_secret!).to be(true)
      expect(Doorkeeper::Application.find(app.id).old_secret).to be_nil
    end

    # A `retained_at` that came back from a job payload or a form is a String,
    # which is never equal to a time — so comparing it would answer false, and
    # false is what this method says when another process ended the grace
    # period first. Said out loud instead, before the lock is taken.
    it "refuses a retained_at that is not a time rather than reporting nothing to clear" do
      app.rotate_secret!
      observed = Doorkeeper::Application.find(app.id).old_secret_created_at

      expect { app.clear_old_secret!(retained_at: observed.to_s) }
        .to raise_error(ArgumentError, /retained_at must be/)

      expect(Doorkeeper::Application.find(app.id).old_secret).to be_present
    end

    it "takes the timestamp back in whichever time class the caller holds it" do
      app.rotate_secret!
      observed = Doorkeeper::Application.find(app.id).old_secret_created_at

      expect(app.clear_old_secret!(retained_at: observed.to_time)).to be(true)
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

      # The two halves of `#secret_matches?` have to agree: that one refuses a
      # nil `secret` before it consults the retained one, so a host asking
      # this predicate which secret a client presented must not be told the
      # old one authenticated a request Doorkeeper rejected.
      it "is false once the current secret is gone, as #secret_matches? is" do
        old_plaintext = app.plaintext_secret
        app.rotate_secret!
        app.update_columns(secret: nil, confidential: false)
        app.reload

        expect(app.old_secret_matches?(old_plaintext)).to be(false)
        expect(app.secret_matches?(old_plaintext)).to be(false)
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

      # README: a `by_uid` override that narrows the columns loaded has to
      # include the rotation columns — the comparison reads them, and a
      # record loaded without them raises rather than compare against
      # nothing.
      it "raises when the record was loaded without the rotation columns" do
        narrowed = Doorkeeper::Application.select(:id, :uid, :secret, :confidential).find(app.id)

        expect { narrowed.secret_matches?("nope") }.to raise_error(ActiveModel::MissingAttributeError)
      end

      it "stops accepting the superseded secret once the grace period ends" do
        old_plaintext = app.plaintext_secret
        app.rotate_secret!
        app.clear_old_secret!

        expect(app.secret_matches?(old_plaintext)).to be(false)
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

      # The crossing of the two features: the retained secret is in the
      # fallback format *and* its grace period has ended. Expiry is read
      # before the comparison, so the dead credential is neither honoured nor
      # re-encoded — a rejected authentication must not write the row.
      context "when the grace period has already expired" do
        before do
          Doorkeeper.configure do
            orm DOORKEEPER_ORM
            hash_application_secrets fallback: :plain
            enable_secret_rotation
            secret_rotation_grace_period 7 * 24 * 60 * 60
          end
          app.update_columns(old_secret: plain_old_secret, old_secret_created_at: 8.days.ago)
        end

        it "rejects the expired old secret" do
          expect(app.secret_matches?(plain_old_secret)).to be(false)
        end

        it "does not rewrite a credential it has already expired" do
          expect { app.secret_matches?(plain_old_secret) }
            .not_to(change { app.reload.attributes.values_at("old_secret", "updated_at") })
        end
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

  describe "secret_rotation_grace_period" do
    let(:old_plaintext) { app.plaintext_secret }

    def enable_rotation_with_grace_period(period)
      Doorkeeper.configure do
        orm DOORKEEPER_ORM
        enable_secret_rotation
        secret_rotation_grace_period period
      end
    end

    # #old_secret_expired? returns false at the nil-grace-period guard before
    # it ever reaches the undated-secret branch, so a retained secret written
    # without a timestamp outlives every deadline that is not configured —
    # while #clear_old_secret! will still clear it.
    it "keeps an undated retained secret alive while no deadline is configured" do
      enable_rotation
      old_plaintext = app.plaintext_secret
      app.rotate_secret!
      app.update_column(:old_secret_created_at, nil)

      expect(app.old_secret_expired?).to be(false)
      expect(app.reload.secret_matches?(old_plaintext)).to be(true)
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

    # Written the way the README and the initializer write it, so that a
    # duration is exercised through the deadline itself and not only through
    # the config reader.
    it "stops accepting it past the grace period" do
      enable_rotation_with_grace_period(7.days)
      old_plaintext
      app.rotate_secret!
      app.update_column(:old_secret_created_at, 8.days.ago)

      expect(app.old_secret_expired?).to be(true)
      expect(app.secret_matches?(old_plaintext)).to be(false)
    end

    # Expiring is not clearing: the deadline decides what authenticates, and
    # the row keeps the value until #clear_old_secret! drops it.
    it "leaves the expired secret in the row until it is cleared" do
      enable_rotation_with_grace_period(7.days)
      old_plaintext
      app.rotate_secret!
      app.update_column(:old_secret_created_at, 8.days.ago)

      expect(app.reload.read_attribute(:old_secret)).to be_present

      app.clear_old_secret!

      expect(app.reload.read_attribute(:old_secret)).to be_nil
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
      # Configuring the deadline alone is what Validations warns about; here
      # it is only the setup for the question being asked.
      allow(Rails.logger).to receive(:warn)

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
  end
end
