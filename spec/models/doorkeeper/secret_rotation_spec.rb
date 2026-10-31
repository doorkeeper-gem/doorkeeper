# frozen_string_literal: true

require "spec_helper"

RSpec.describe "client secret rotation" do
  include_context "with client secret rotation"

  let(:app) { FactoryBot.create(:application) }

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

    it "is false with the option on but the column missing" do
      enable_rotation
      allow(Doorkeeper::Application).to receive(:column_names)
        .and_return(Doorkeeper::Application.column_names - ["old_secret"])

      expect(Doorkeeper::Application.secret_rotation_enabled?).to be(false)
    end

    it "is false with the option on but the timestamp column missing" do
      enable_rotation
      allow(Doorkeeper::Application).to receive(:column_names)
        .and_return(Doorkeeper::Application.column_names - ["old_secret_created_at"])

      expect(Doorkeeper::Application.secret_rotation_enabled?).to be(false)
    end
  end

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

    it "answers without a logger to warn through" do
      allow(Rails).to receive(:logger).and_return(nil)

      expect(model.secret_rotation_enabled?).to be(false)
    end

    # On the real model: earlier `column_names` stubs would otherwise leave it already warned.
    it "warns once on the real application model" do
      allow(Doorkeeper::Application).to receive(:column_names)
        .and_return(Doorkeeper::Application.column_names - ["old_secret"])
      expect(Rails.logger).to receive(:warn).with(/enable_secret_rotation is set/).once

      2.times { Doorkeeper::Application.secret_rotation_enabled? }
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
        old_plaintext = retain_current_secret(app)

        expect(app.old_secret_matches?(old_plaintext)).to be(true)
      end

      it "is false for the current secret" do
        retain_current_secret(app)
        new_plaintext = app.plaintext_secret

        expect(app.old_secret_matches?(new_plaintext)).to be(false)
      end

      it "is false for a nil input" do
        retain_current_secret(app)

        expect(app.old_secret_matches?(nil)).to be(false)
      end

      it "is false for an application with no secret at all" do
        public_app = FactoryBot.create(:application, confidential: false)
        public_app.update_column(:secret, nil)

        expect(public_app.old_secret_matches?("anything")).to be(false)
      end

      it "is false once the current secret is gone, as #secret_matches? is" do
        old_plaintext = retain_current_secret(app)
        app.update_columns(secret: nil, confidential: false)
        app.reload

        expect(app.old_secret_matches?(old_plaintext)).to be(false)
        expect(app.secret_matches?(old_plaintext)).to be(false)
      end
    end
  end

  describe "#secret_matches?" do
    context "when rotation is disabled" do
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
        retain_current_secret(app)
        new_plaintext = app.plaintext_secret

        expect(app.secret_matches?(new_plaintext)).to be(true)
      end

      it "accepts the superseded secret" do
        old_plaintext = retain_current_secret(app)

        expect(app.secret_matches?(old_plaintext)).to be(true)
      end

      it "rejects an unrelated secret" do
        retain_current_secret(app)

        expect(app.secret_matches?("nope")).to be(false)
      end

      it "rejects a nil secret" do
        retain_current_secret(app)

        expect(app.secret_matches?(nil)).to be(false)
      end

      it "raises when the record was loaded without the rotation columns" do
        narrowed = Doorkeeper::Application.select(:id, :uid, :secret, :confidential).find(app.id)

        expect { narrowed.secret_matches?("nope") }.to raise_error(ActiveModel::MissingAttributeError)
      end

      it "compares twice even when nothing has been rotated" do
        expect(Doorkeeper::SecretStoring::Plain)
          .to receive(:secret_matches?).twice.and_call_original

        app.secret_matches?("nope")
      end

      it "compares twice when an old secret is stored" do
        retain_current_secret(app)

        expect(Doorkeeper::SecretStoring::Plain)
          .to receive(:secret_matches?).twice.and_call_original

        app.secret_matches?("nope")
      end

      it "compares twice even when the current secret already matched" do
        retain_current_secret(app)
        new_plaintext = app.plaintext_secret

        expect(Doorkeeper::SecretStoring::Plain)
          .to receive(:secret_matches?).twice.and_call_original

        expect(app.secret_matches?(new_plaintext)).to be(true)
      end

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

      it "writes nothing when asked of an application that never rotated" do
        app.update_columns(old_secret: nil, old_secret_created_at: nil)
        app.update_column(:secret, "legacy plain secret")
        fresh = Doorkeeper::Application.find(app.id)

        expect(fresh.old_secret_matches?("legacy plain secret")).to be(false)
        expect(Doorkeeper::Application.find(app.id).secret).to eq("legacy plain secret")
      end
    end
  end

  describe ".by_uid_and_secret" do
    before { enable_rotation }

    it "finds the application by its superseded secret" do
      old_plaintext = retain_current_secret(app)

      expect(Doorkeeper::Application.by_uid_and_secret(app.uid, old_plaintext)).to eq(app)
    end

    it "finds the application by its current secret" do
      retain_current_secret(app)
      new_plaintext = app.plaintext_secret

      expect(Doorkeeper::Application.by_uid_and_secret(app.uid, new_plaintext)).to eq(app)
    end
  end
end
