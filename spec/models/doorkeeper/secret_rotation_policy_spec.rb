# frozen_string_literal: true

require "spec_helper"

RSpec.describe "client secret rotation grace period and hook" do
  include_context "with client secret rotation"

  let(:app) { FactoryBot.create(:application) }

  describe "Doorkeeper.config#enable_secret_rotation?" do
    it "warns when the ORM is not Active Record" do
      allow(Doorkeeper).to receive(:setup)
      expect(Rails.logger).to receive(:warn).with(/implemented for the active_record ORM/)

      Doorkeeper.configure do
        orm :mongoid
        enable_secret_rotation
      end
    end
  end

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

    it "refuses an infinite grace period" do
      expect do
        Doorkeeper.configure do
          orm DOORKEEPER_ORM
          enable_secret_rotation
          secret_rotation_grace_period Float::INFINITY
        end
      end.to raise_error(ArgumentError, /secret_rotation_grace_period/)
    end

    it "refuses a complex number" do
      expect do
        Doorkeeper.configure do
          orm DOORKEEPER_ORM
          enable_secret_rotation
          secret_rotation_grace_period Complex(1, 0)
        end
      end.to raise_error(ArgumentError, /secret_rotation_grace_period/)
    end

    it "warns when it is configured without enable_secret_rotation" do
      expect(Rails.logger).to receive(:warn).with(/without enable_secret_rotation/)

      Doorkeeper.configure do
        orm DOORKEEPER_ORM
        secret_rotation_grace_period 7.days
      end
    end

    it "warns when after_old_secret_used is configured without enable_secret_rotation" do
      expect(Rails.logger).to receive(:warn).with(/without enable_secret_rotation/)

      Doorkeeper.configure do
        orm DOORKEEPER_ORM
        after_old_secret_used ->(_application) {}
      end
    end

    it "does not warn once enable_secret_rotation is set" do
      expect(Rails.logger).not_to receive(:warn).with(/without enable_secret_rotation/)

      Doorkeeper.configure do
        orm DOORKEEPER_ORM
        enable_secret_rotation
        secret_rotation_grace_period 7.days
        after_old_secret_used ->(_application) {}
      end
    end
  end

  describe "Doorkeeper.config#after_old_secret_used" do
    it "accepts a lambda taking the application" do
      hook = ->(_application) {}

      Doorkeeper.configure do
        orm DOORKEEPER_ORM
        enable_secret_rotation
        after_old_secret_used hook
      end

      expect(Doorkeeper.config.after_old_secret_used).to eq(hook)
    end

    it "accepts a block" do
      seen = []

      Doorkeeper.configure do
        orm DOORKEEPER_ORM
        enable_secret_rotation
        after_old_secret_used { |application| seen << application.uid }
      end

      Doorkeeper.config.after_old_secret_used.call(app)
      expect(seen).to eq([app.uid])
    end

    it "refuses a value that cannot be called" do
      expect do
        Doorkeeper.configure do
          orm DOORKEEPER_ORM
          enable_secret_rotation
          after_old_secret_used :nope
        end
      end.to raise_error(ArgumentError, /after_old_secret_used.*:nope/)
    end

    it "refuses a lambda that does not take the application" do
      expect do
        Doorkeeper.configure do
          orm DOORKEEPER_ORM
          enable_secret_rotation
          after_old_secret_used -> {}
        end
      end.to raise_error(ArgumentError, /after_old_secret_used/)
    end

    it "refuses a lambda that takes the application as a keyword" do
      expect do
        Doorkeeper.configure do
          orm DOORKEEPER_ORM
          enable_secret_rotation
          after_old_secret_used ->(application:) {}
        end
      end.to raise_error(ArgumentError, /after_old_secret_used/)
    end

    it "refuses a proc with a required keyword" do
      expect do
        Doorkeeper.configure do
          orm DOORKEEPER_ORM
          enable_secret_rotation
          after_old_secret_used proc { |application:| }
        end
      end.to raise_error(ArgumentError, /after_old_secret_used/)
    end

    it "refuses a lambda needing two positionals before a splat" do
      expect do
        Doorkeeper.configure do
          orm DOORKEEPER_ORM
          enable_secret_rotation
          after_old_secret_used ->(_application, _other, *_rest) {}
        end
      end.to raise_error(ArgumentError, /after_old_secret_used/)
    end

    it "accepts a lambda with optional arguments after the application" do
      hook = ->(_application, _detail = nil, **_options) {}

      Doorkeeper.configure do
        orm DOORKEEPER_ORM
        enable_secret_rotation
        after_old_secret_used hook
      end

      expect(Doorkeeper.config.after_old_secret_used).to eq(hook)
    end

    it "accepts a lambda taking a splat" do
      hook = ->(*_args) {}

      Doorkeeper.configure do
        orm DOORKEEPER_ORM
        enable_secret_rotation
        after_old_secret_used hook
      end

      expect(Doorkeeper.config.after_old_secret_used).to eq(hook)
    end

    it "accepts a Method object taking the application" do
      reporter = Object.new
      def reporter.report(_application); end
      hook = reporter.method(:report)

      Doorkeeper.configure do
        orm DOORKEEPER_ORM
        enable_secret_rotation
        after_old_secret_used hook
      end

      expect(Doorkeeper.config.after_old_secret_used).to eq(hook)
    end

    it "accepts a callable that does not report an arity" do
      hook = Object.new
      def hook.call(_application); end

      Doorkeeper.configure do
        orm DOORKEEPER_ORM
        enable_secret_rotation
        after_old_secret_used hook
      end

      expect(Doorkeeper.config.after_old_secret_used).to eq(hook)
    end

    it "refuses a lambda that wants more than the application" do
      expect do
        Doorkeeper.configure do
          orm DOORKEEPER_ORM
          enable_secret_rotation
          after_old_secret_used ->(_application, _extra) {}
        end
      end.to raise_error(ArgumentError, /after_old_secret_used/)
    end
  end

  describe "#secret_matches? with the fallback strategy and rotation enabled" do
    let(:plain_old_secret) { "plain text old secret" }

    before do
      Doorkeeper.configure do
        orm DOORKEEPER_ORM
        hash_application_secrets fallback: :plain
        enable_secret_rotation
      end

      app.update_columns(old_secret: plain_old_secret, old_secret_created_at: Time.now.utc)
    end

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

    it "stops accepting it past the grace period" do
      enable_rotation_with_grace_period(7.days)
      old_plaintext
      app.rotate_secret!
      app.update_column(:old_secret_created_at, 8.days.ago)

      expect(app.old_secret_expired?).to be(true)
      expect(app.secret_matches?(old_plaintext)).to be(false)
    end

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

    it "does not remove the expired secret" do
      enable_rotation_with_grace_period(7 * 24 * 60 * 60)
      old_plaintext
      app.rotate_secret!
      app.update_column(:old_secret_created_at, 8.days.ago)

      app.secret_matches?(old_plaintext)

      expect(app.reload.old_secret).to be_present
    end

    it "treats an undated old secret as expired" do
      enable_rotation_with_grace_period(7 * 24 * 60 * 60)
      old_plaintext
      app.rotate_secret!
      app.update_column(:old_secret_created_at, nil)

      expect(app.old_secret_expired?).to be(true)
      expect(app.secret_matches?(old_plaintext)).to be(false)
    end

    it "reports an application that never rotated as not expired" do
      enable_rotation_with_grace_period(7 * 24 * 60 * 60)

      expect(app.old_secret).to be_nil
      expect(app.old_secret_expired?).to be(false)
    end

    it "reports nothing as expired while rotation is disabled" do
      allow(Rails.logger).to receive(:warn)

      Doorkeeper.configure do
        orm DOORKEEPER_ORM
        secret_rotation_grace_period 7 * 24 * 60 * 60
      end
      app.update_columns(old_secret: "retained", old_secret_created_at: 8.days.ago)

      expect(app.old_secret_expired?).to be(false)
      expect(app.secret_matches?(app.plaintext_secret)).to be(true)
    end

    it "reports nothing as expired with the option on but the column missing" do
      enable_rotation_with_grace_period(7 * 24 * 60 * 60)
      app.update_columns(old_secret: "retained", old_secret_created_at: 8.days.ago)
      allow(Doorkeeper::Application).to receive(:column_names)
        .and_return(Doorkeeper::Application.column_names - ["old_secret"])

      expect(app.old_secret_expired?).to be(false)
    end

    it "still compares twice for an expired old secret" do
      enable_rotation_with_grace_period(7 * 24 * 60 * 60)
      app.rotate_secret!
      app.update_column(:old_secret_created_at, 8.days.ago)

      expect(Doorkeeper::SecretStoring::Plain)
        .to receive(:secret_matches?).twice.and_call_original

      app.secret_matches?("nope")
    end
  end
end
