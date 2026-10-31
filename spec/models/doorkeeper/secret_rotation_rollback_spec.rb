# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Application#rotate_secret! when the write fails" do
  include_context "with client secret rotation"

  let(:app) { FactoryBot.create(:application) }

  before { enable_rotation }

  context "when the write fails" do
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

    it "puts the in-memory attributes back" do
      stored = app.secret

      expect { app.rotate_secret! }.to raise_error(ActiveRecord::RecordInvalid)

      expect(app.secret).to eq(stored)
      expect(app.old_secret).to be_nil
      expect(app.old_secret_created_at).to be_nil
    end

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

    it "puts the instance back to the stored secret when the COMMIT is lost with the connection" do
      skip "ActiveRecord::ConnectionFailed arrived in Rails 7.1" unless defined?(::ActiveRecord::ConnectionFailed)

      Doorkeeper.configure do
        orm DOORKEEPER_ORM
        hash_application_secrets
        enable_secret_rotation
      end

      stub_const("LostCommitApp", build_application_model)
      record = LostCommitApp.create!(FactoryBot.attributes_for(:application))
      stored = record.secret
      plaintext = record.plaintext_secret
      lose_commit(LostCommitApp.connection)

      expect { record.rotate_secret!(revoke_old: true) }
        .to raise_error(::ActiveRecord::ConnectionFailed)

      expect(record.secret).to eq(stored)
      expect(record.old_secret_created_at).to be_nil
      expect(record).not_to be_changed
      expect(record.plaintext_secret).to eq(plaintext)
      expect(LostCommitApp.find(record.id).secret_matches?(record.plaintext_secret)).to be(true)
    end

    it "keeps the committed plaintext when a host after_commit callback raises" do
      Doorkeeper.configure do
        orm DOORKEEPER_ORM
        hash_application_secrets
        enable_secret_rotation
      end

      klass = build_application_model
      committed = klass.create!(FactoryBot.attributes_for(:application))
      klass.after_commit { raise "boom" }

      expect { committed.rotate_secret! }.to raise_error(RuntimeError, "boom")

      stored = klass.find(committed.id)
      expect(stored.old_secret).to be_present
      expect(committed.plaintext_secret).to be_present
      expect(stored.secret_matches?(committed.plaintext_secret)).to be(true)
    end

    # The same read-back with no row left to answer it: a host `after_commit`
    # callback that deletes the row and then raises lands in the rescue with
    # the rotation committed and nothing to confirm it against. It answers as
    # an uncommitted rotation does, and the reload that follows fails on the
    # missing row with the callback's error as its cause, rather than the
    # instance being left claiming a secret no row holds.
    it "fails on the missing row when a host after_commit callback deletes it and raises" do
      klass = build_application_model
      record = klass.create!(FactoryBot.attributes_for(:application))
      klass.after_commit do |app|
        klass.where(id: app.id).delete_all
        raise "boom"
      end

      expect { record.rotate_secret! }
        .to raise_error(ActiveRecord::RecordNotFound) { |error|
          expect(error.cause).to be_a(RuntimeError)
          expect(error.cause.message).to eq("boom")
        }
    end
  end

  context "when the failure lands after validation" do
    it "leaves the instance clean enough to retry" do
      enable_rotation
      klass = build_application_model
      record = klass.create!(FactoryBot.attributes_for(:application))
      klass.define_method(:boom) { raise "boom" }
      klass.after_save :boom

      expect { record.rotate_secret! }.to raise_error(RuntimeError, "boom")
      expect(record.changed).to be_empty

      klass.skip_callback(:save, :after, :boom)
      expect { record.rotate_secret! }.not_to raise_error
      expect { record.clear_old_secret! }.not_to raise_error
    end
  end

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
end
