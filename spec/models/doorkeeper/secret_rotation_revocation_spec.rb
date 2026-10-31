# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Application#rotate_secret!(revoke_tokens: true)" do
  include_context "with client secret rotation"

  let(:app) { FactoryBot.create(:application) }

  before { enable_rotation }

  context "with revoke_tokens: true" do
    let!(:token) { FactoryBot.create(:access_token, application: app) }
    let!(:grant) { FactoryBot.create(:access_grant, application: app) }

    it "revokes the access tokens already issued" do
      app.rotate_secret!(revoke_old: true, revoke_tokens: true)

      expect(token.reload).to be_revoked
    end

    it "revokes the unredeemed authorization codes" do
      app.rotate_secret!(revoke_old: true, revoke_tokens: true)

      expect(grant.reload).to be_revoked
    end

    it "revokes a credential whose revocation was only scheduled" do
      scheduled = FactoryBot.create(:access_token, application: app, revoked_at: 1.hour.from_now)
      scheduled_grant = FactoryBot.create(:access_grant, application: app, revoked_at: 1.hour.from_now)

      expect(scheduled).not_to be_revoked

      app.rotate_secret!(revoke_old: true, revoke_tokens: true)

      expect(scheduled.reload).to be_revoked
      expect(scheduled_grant.reload).to be_revoked
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

    it "still retains the superseded secret when revoke_old is not asked for" do
      old_plaintext = app.plaintext_secret

      app.rotate_secret!(revoke_tokens: true)

      expect(app.reload.secret_matches?(old_plaintext)).to be(true)
      expect(token.reload).to be_revoked
      expect(grant.reload).to be_revoked
    end

    it "revokes nothing unless asked" do
      app.rotate_secret!

      expect(token.reload).not_to be_revoked
      expect(grant.reload).not_to be_revoked
    end

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

  context "when the write fails" do
    it "still revokes the issued credentials when a host after_commit callback raises" do
      # Named: the associations the sweep goes through derive their inverse from the class name.
      stub_const("CommittingApp", build_application_model)
      boom = false
      CommittingApp.after_commit { raise "boom" if boom }
      committed = CommittingApp.create!(FactoryBot.attributes_for(:application))
      token = FactoryBot.create(:access_token, application_id: committed.id)
      grant = FactoryBot.create(:access_grant, application_id: committed.id)
      boom = true

      expect { committed.rotate_secret!(revoke_old: true, revoke_tokens: true) }
        .to raise_error(RuntimeError, "boom")

      boom = false
      expect(token.reload).to be_revoked
      expect(grant.reload).to be_revoked
    end

    it "does not revoke the issued credentials when the commit itself fails" do
      stub_const("RefusingCommitApp", build_application_model)
      boom = false
      RefusingCommitApp.before_commit { raise "boom" if boom }
      record = RefusingCommitApp.create!(FactoryBot.attributes_for(:application))
      token = FactoryBot.create(:access_token, application_id: record.id)
      grant = FactoryBot.create(:access_grant, application_id: record.id)
      stored = record.secret
      boom = true

      expect { record.rotate_secret!(revoke_old: true, revoke_tokens: true) }
        .to raise_error(RuntimeError, "boom")

      boom = false
      expect(RefusingCommitApp.find(record.id).secret).to eq(stored)
      expect(token.reload).not_to be_revoked
      expect(grant.reload).not_to be_revoked
    end

    it "does not revoke the issued credentials when the COMMIT is lost with the connection" do
      skip "ActiveRecord::ConnectionFailed arrived in Rails 7.1" unless defined?(::ActiveRecord::ConnectionFailed)

      stub_const("LostCommitApp", build_application_model)
      record = LostCommitApp.create!(FactoryBot.attributes_for(:application))
      token = FactoryBot.create(:access_token, application_id: record.id)
      grant = FactoryBot.create(:access_grant, application_id: record.id)
      stored = record.secret
      lose_commit(LostCommitApp.connection)

      expect { record.rotate_secret!(revoke_old: true, revoke_tokens: true) }
        .to raise_error(::ActiveRecord::ConnectionFailed, "lost during COMMIT")

      expect(LostCommitApp.find(record.id).secret).to eq(stored)
      expect(token.reload).not_to be_revoked
      expect(grant.reload).not_to be_revoked
    end

    it "does not sweep when the row is gone by the time it is read back" do
      skip "ActiveRecord::ConnectionFailed arrived in Rails 7.1" unless defined?(::ActiveRecord::ConnectionFailed)

      stub_const("LostCommitApp", build_application_model)
      record = LostCommitApp.create!(FactoryBot.attributes_for(:application))
      token = FactoryBot.create(:access_token, application_id: record.id)
      connection = LostCommitApp.connection
      allow(connection).to receive(:release_savepoint).and_wrap_original do |_original, name|
        connection.rollback_to_savepoint(name)
        LostCommitApp.where(id: record.id).delete_all
        raise ::ActiveRecord::ConnectionFailed, "lost during COMMIT"
      end
      allow(connection).to receive(:throw_away!)

      expect { record.rotate_secret!(revoke_old: true, revoke_tokens: true) }
        .to raise_error(::ActiveRecord::RecordNotFound) { |error|
          expect(error.cause).to be_a(::ActiveRecord::ConnectionFailed)
        }

      expect(token.reload).not_to be_revoked
    end

    # Same read-back via after_commit; needs nothing Rails 7.1 added, so it runs on every Rails.
    it "does not sweep when the row is gone by the time a host after_commit callback raises" do
      stub_const("VanishingApp", build_application_model)
      boom = false
      VanishingApp.after_commit do |app|
        next unless boom

        VanishingApp.where(id: app.id).delete_all
        raise "boom"
      end
      record = VanishingApp.create!(FactoryBot.attributes_for(:application))
      token = FactoryBot.create(:access_token, application_id: record.id)
      grant = FactoryBot.create(:access_grant, application_id: record.id)
      boom = true

      expect { record.rotate_secret!(revoke_old: true, revoke_tokens: true) }
        .to raise_error(::ActiveRecord::RecordNotFound) { |error|
          expect(error.cause).to be_a(RuntimeError)
          expect(error.cause.message).to eq("boom")
        }

      expect(token.reload).not_to be_revoked
      expect(grant.reload).not_to be_revoked
    end
  end

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

    # The transaction that matters is the writer's, which `with_primary_role` selects.
    it "consults the connection selected by with_primary_role" do
      primary_role_selected = false
      allow(Doorkeeper::Application).to receive(:with_primary_role).and_wrap_original do |original, &block|
        primary_role_selected = true
        original.call(&block)
      ensure
        primary_role_selected = false
      end

      checked_under_primary_role = nil
      allow(app).to receive(:ensure_revocation_can_follow_commit!).and_wrap_original do |original|
        checked_under_primary_role = primary_role_selected
        original.call
      end

      app.rotate_secret!(revoke_old: true, revoke_tokens: true)

      expect(checked_under_primary_role).to be true
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

    # Reset the lease inside the example: DatabaseCleaner's `before` leases the connection sticky.
    context "with permanent_connection_checkout = :disallowed" do
      def with_disallowed_permanent_checkout
        skip "Rails < 7.2 has no permanent_connection_checkout" unless ActiveRecord.respond_to?(:permanent_connection_checkout=)

        lease = Doorkeeper::Application.connection_pool.send(:connection_lease)
        sticky_was = lease.sticky
        setting_was = ActiveRecord.permanent_connection_checkout
        lease.sticky = nil
        ActiveRecord.permanent_connection_checkout = :disallowed
        yield
      ensure
        ActiveRecord.permanent_connection_checkout = setting_was if setting_was
        lease.sticky = sticky_was if lease
      end

      it "rotates and revokes outside a transaction" do
        with_disallowed_permanent_checkout do
          expect { app.rotate_secret!(revoke_old: true, revoke_tokens: true) }.not_to raise_error
        end

        expect(token.reload).to be_revoked
      end

      it "is still refused inside a joinable transaction" do
        with_disallowed_permanent_checkout do
          expect do
            Doorkeeper::Application.transaction do
              app.rotate_secret!(revoke_old: true, revoke_tokens: true)
            end
          end.to raise_error(Doorkeeper::Errors::SecretRotationInTransaction)
        end

        expect(token.reload).not_to be_revoked
      end
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
end
