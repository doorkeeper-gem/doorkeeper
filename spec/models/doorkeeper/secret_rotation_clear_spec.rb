# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Application#clear_old_secret!" do
  include_context "with client secret rotation"

  let(:app) { FactoryBot.create(:application) }

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

      it "clears a retained secret left behind with no timestamp" do
        app.update_columns(old_secret: "undated", old_secret_created_at: nil)

        expect(app.clear_old_secret!).to be(true)
        expect(app.reload.old_secret).to be_nil
      end

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

      context "when the failure lands after the COMMIT" do
        it "keeps the cleared columns when a host after_commit callback raises" do
          klass = build_application_model
          boom = false
          klass.after_commit { raise "boom" if boom }
          record = klass.create!(FactoryBot.attributes_for(:application))
          record.rotate_secret!
          record.reload
          boom = true

          expect { record.clear_old_secret! }.to raise_error(RuntimeError, "boom")

          boom = false
          expect(record.old_secret).to be_nil
          expect(record).not_to be_changed
          expect(klass.find(record.id).old_secret).to be_nil
        end

        it "puts the retained secret back on the instance when the COMMIT is lost with the connection" do
          skip "ActiveRecord::ConnectionFailed arrived in Rails 7.1" unless defined?(::ActiveRecord::ConnectionFailed)

          stub_const("LostCommitApp", build_application_model)
          record = LostCommitApp.create!(FactoryBot.attributes_for(:application))
          record.rotate_secret!
          record.reload
          retained = record.old_secret
          lose_commit(LostCommitApp.connection)

          expect { record.clear_old_secret! }
            .to raise_error(::ActiveRecord::ConnectionFailed, "lost during COMMIT")

          expect(record.old_secret).to eq(retained)
          expect(record.old_secret_created_at).to be_present
          expect(record).not_to be_changed
          expect(LostCommitApp.find(record.id).old_secret).to eq(retained)
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

        it "puts the in-memory attributes back" do
          expect { app.clear_old_secret! }.to raise_error(ActiveRecord::RecordInvalid)

          expect(app.old_secret).to be_present
          expect(app.old_secret_created_at).to be_present
        end
      end
    end
  end

  describe "once the grace period has been ended" do
    before { enable_rotation }

    it "stops #secret_matches? accepting the superseded secret" do
      old_plaintext = app.plaintext_secret
      app.rotate_secret!
      app.clear_old_secret!

      expect(app.secret_matches?(old_plaintext)).to be(false)
    end

    it "stops .by_uid_and_secret finding the application by it" do
      old_plaintext = app.plaintext_secret
      app.rotate_secret!
      app.clear_old_secret!

      expect(Doorkeeper::Application.by_uid_and_secret(app.uid, old_plaintext)).to be_nil
    end
  end

  describe "with nothing to clear" do
    before { enable_rotation }

    it "refuses an unsaved record" do
      expect { Doorkeeper::Application.new.clear_old_secret! }
        .to raise_error(ActiveRecord::RecordNotSaved, /needs a persisted/)
    end

    it "finds no grace period after a rotation that had no secret to retain" do
      public_app = FactoryBot.create(:application, confidential: false)
      public_app.update_column(:secret, nil)
      public_app.rotate_secret!

      expect(public_app.clear_old_secret!).to be(false)
      expect(public_app.reload.old_secret_created_at).to be_nil
    end
  end
end
