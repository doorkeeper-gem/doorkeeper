# frozen_string_literal: true

require "spec_helper"
require "bcrypt"

RSpec.describe "Application#rotate_secret!" do
  include_context "with client secret rotation"

  let(:app) { FactoryBot.create(:application) }

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

      it "points at the call that ends a grace period rather than at #renew_secret" do
        expect { app.rotate_secret! }
          .to raise_error(Doorkeeper::Errors::SecretRotationNotEnabled, /rotate_secret!\(revoke_old: true\)/)
      end

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

      context "when the record was never saved" do
        it "refuses to rotate" do
          enable_rotation
          record = Doorkeeper::Application.new(
            FactoryBot.attributes_for(:application).merge(secret: "known-secret"),
          )

          expect { record.rotate_secret! }.to raise_error(ActiveRecord::RecordNotSaved, /needs a persisted/)
          expect(record).not_to be_persisted
        end
      end

      context "when the record was destroyed" do
        it "says so rather than asking for a save" do
          enable_rotation
          app.destroy!

          expect { app.rotate_secret! }
            .to raise_error(ActiveRecord::RecordNotSaved, /needs a persisted.*has been destroyed/)
        end
      end

      context "when the record carries unsaved changes" do
        before { app.name = "renamed but not saved" }

        it "refuses to rotate" do
          expect { app.rotate_secret! }.to raise_error(RuntimeError, /unpersisted changes/)
        end

        it "keeps the caller's own changes" do
          expect { app.rotate_secret! }.to raise_error(RuntimeError)

          expect(app.name).to eq("renamed but not saved")
        end

        it "keeps the caller's value on the rotation columns" do
          app.secret = "pending"

          expect { app.rotate_secret! }.to raise_error(RuntimeError)

          expect(app.secret).to eq("pending")
        end
      end

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

      context "when there is no secret to retain" do
        let(:public_app) { FactoryBot.create(:application, confidential: false) }

        before { public_app.update_column(:secret, nil) }

        it "retains nothing and dates nothing" do
          public_app.rotate_secret!

          expect(public_app.reload.old_secret).to be_nil
          expect(public_app.old_secret_created_at).to be_nil
          expect(public_app.secret).to be_present
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
      end
    end

    context "with hashed application secrets" do
      include_context "with application hashing enabled"

      before { enable_secret_rotation_on_top_of_hashing }

      # Each `Doorkeeper.configure` replaces the whole config, so this call restates the first.
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

      it "keeps the retained digest verifiable" do
        old_plaintext = app.plaintext_secret
        stored = app.secret

        app.rotate_secret!

        expect(app.reload.old_secret).to eq(stored)
        expect(app.secret_matches?(old_plaintext)).to be(true)
      end
    end

    context "with a secret the fallback strategy wrote" do
      let!(:legacy) { FactoryBot.create(:application) }
      # let!: after a rotation `legacy.secret` is the new digest, and `fallback: :plain` accepts it.
      let!(:legacy_plaintext) { legacy.secret }

      before do
        Doorkeeper.configure do
          orm DOORKEEPER_ORM
          hash_application_secrets fallback: :plain
          enable_secret_rotation
        end
      end

      it "retains it re-derived under the active strategy" do
        expected = Doorkeeper::SecretStoring::Sha256Hash.transform_secret(legacy_plaintext)

        legacy.rotate_secret!

        expect(legacy.reload.old_secret).to eq(expected)
      end

      it "leaves no plain text behind" do
        legacy.rotate_secret!

        expect(legacy.reload.old_secret).not_to eq(legacy_plaintext)
      end

      it "keeps the superseded secret authenticating" do
        legacy.rotate_secret!

        expect(legacy.reload.secret_matches?(legacy_plaintext)).to be(true)
      end

      context "with bcrypt application secrets" do
        before do
          Doorkeeper.configure do
            orm DOORKEEPER_ORM
            hash_application_secrets using: "::Doorkeeper::SecretStoring::BCrypt", fallback: :plain
            enable_secret_rotation
          end
        end

        it "retains a digest bcrypt recognises as its own" do
          legacy.rotate_secret!

          retained = legacy.reload.old_secret

          expect(retained).not_to eq(legacy_plaintext)
          expect(Doorkeeper::SecretStoring::BCrypt.recognizes_stored_secret?(retained)).to be(true)
        end

        it "keeps the superseded secret authenticating" do
          legacy.rotate_secret!

          expect(legacy.reload.secret_matches?(legacy_plaintext)).to be(true)
        end
      end

      context "with a strategy whose store_secret wraps the stored value" do
        let(:strategy) do
          Class.new(Doorkeeper::SecretStoring::Base) do
            def self.transform_secret(plain_secret) = "custom:#{plain_secret}"

            def self.store_secret(resource, attribute, plain_secret)
              "v1|#{transform_secret(plain_secret)}".tap do |value|
                resource.public_send(:"#{attribute}=", value)
              end
            end

            def self.secret_matches?(input, stored) = stored == "v1|#{transform_secret(input)}"

            def self.recognizes_stored_secret?(stored) = stored.to_s.start_with?("v1|")
          end
        end

        before do
          stub_const("EnvelopeSecretStrategy", strategy)
          allow(Doorkeeper.config).to receive(:application_secret_strategy)
            .and_return(EnvelopeSecretStrategy)
        end

        it "retains the secret in the form store_secret writes" do
          legacy.rotate_secret!

          expect(legacy.reload.old_secret).to eq("v1|custom:#{legacy_plaintext}")
        end

        it "keeps the superseded secret authenticating" do
          legacy.rotate_secret!

          expect(legacy.reload.secret_matches?(legacy_plaintext)).to be(true)
        end
      end

      context "when the active strategy does not implement recognizes_stored_secret?" do
        let(:strategy) do
          Class.new do
            def self.transform_secret(plain_secret) = "custom:#{plain_secret}"

            def self.store_secret(resource, attribute, plain_secret)
              transform_secret(plain_secret).tap do |value|
                resource.public_send(:"#{attribute}=", value)
              end
            end

            def self.restore_secret(_resource, _attribute) = raise(NotImplementedError)

            def self.allows_restoring_secrets? = false

            def self.validate_for(_model) = true

            def self.secret_matches?(input, stored) = transform_secret(input) == stored
          end
        end

        before do
          stub_const("CustomSecretStrategy", strategy)
          Doorkeeper.configure do
            orm DOORKEEPER_ORM
            hash_application_secrets fallback: :plain
            enable_secret_rotation
          end
          allow(Doorkeeper.config).to receive(:application_secret_strategy)
            .and_return(CustomSecretStrategy)
        end

        it "retains the fallback-written secret as stored rather than re-deriving or raising" do
          expect { legacy.rotate_secret! }.not_to raise_error

          expect(legacy.reload.old_secret).to eq(legacy_plaintext)
        end
      end

      context "when the fallback strategy cannot restore it" do
        let!(:legacy) do
          Doorkeeper.configure do
            orm DOORKEEPER_ORM
            hash_application_secrets
          end
          FactoryBot.create(:application)
        end

        before do
          Doorkeeper.configure do
            orm DOORKEEPER_ORM
            hash_application_secrets using: "::Doorkeeper::SecretStoring::BCrypt",
                                     fallback: "::Doorkeeper::SecretStoring::Sha256Hash"
            enable_secret_rotation
          end
        end

        it "carries the stored secret over verbatim" do
          stored = legacy.secret

          legacy.rotate_secret!

          expect(legacy.reload.old_secret).to eq(stored)
        end
      end

      context "when no fallback strategy is configured" do
        before do
          Doorkeeper.configure do
            orm DOORKEEPER_ORM
            hash_application_secrets
            enable_secret_rotation
          end
        end

        it "carries the stored secret over verbatim" do
          legacy.rotate_secret!

          expect(legacy.reload.old_secret).to eq(legacy_plaintext)
        end
      end
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
end
