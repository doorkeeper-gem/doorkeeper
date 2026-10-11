# frozen_string_literal: true

require "spec_helper"
require "rake"

RSpec.describe "doorkeeper rake tasks" do
  before do
    Rake::Task.define_task(:environment) unless Rake::Task.task_defined?(:environment)
    Doorkeeper::Rake.load_tasks unless Rake::Task.task_defined?("doorkeeper:db:cleanup")
  end

  describe "doorkeeper:db:cleanup" do
    it "removes revoked and expired tokens and grants, keeping active ones" do
      revoked_token = FactoryBot.create(:access_token, revoked_at: 1.hour.ago)
      expired_token = FactoryBot.create(:access_token, expires_in: 1, created_at: 10.days.ago)
      active_token = FactoryBot.create(:access_token)
      revoked_grant = FactoryBot.create(:access_grant, revoked_at: 1.hour.ago)
      expired_grant = FactoryBot.create(:access_grant, expires_in: 1, created_at: 10.days.ago)

      task = Rake::Task["doorkeeper:db:cleanup"]
      task.all_prerequisite_tasks.each(&:reenable)
      task.reenable
      task.invoke

      expect(Doorkeeper::AccessToken.exists?(revoked_token.id)).to be(false)
      expect(Doorkeeper::AccessToken.exists?(expired_token.id)).to be(false)
      expect(Doorkeeper::AccessToken.exists?(active_token.id)).to be(true)
      expect(Doorkeeper::AccessGrant.exists?(revoked_grant.id)).to be(false)
      expect(Doorkeeper::AccessGrant.exists?(expired_grant.id)).to be(false)
    end

    it "keeps expired tokens that carry a refresh token" do
      refreshable_token = FactoryBot.create(
        :access_token,
        expires_in: 1,
        created_at: 10.days.ago,
        use_refresh_token: true,
      )

      task = Rake::Task["doorkeeper:db:cleanup:expired_tokens"]
      task.reenable
      task.invoke

      expect(Doorkeeper::AccessToken.exists?(refreshable_token.id)).to be(true)
    end

    # `revoke_previous_access_token_on_refresh false` revokes the refresh
    # token on its own and leaves `revoked_at` empty, so these records are
    # out of reach of the revoked_tokens task.
    it "removes expired tokens whose refresh token was revoked on its own" do
      dead_token = FactoryBot.create(
        :access_token, expires_in: 1, created_at: 10.days.ago, use_refresh_token: true,
      )
      dead_token.update_column(:refresh_token_revoked_at, 9.days.ago)
      live_access_token = FactoryBot.create(:access_token, use_refresh_token: true)
      live_access_token.update_column(:refresh_token_revoked_at, 1.minute.ago)

      task = Rake::Task["doorkeeper:db:cleanup:expired_tokens"]
      task.reenable
      task.invoke

      expect(Doorkeeper::AccessToken.exists?(dead_token.id)).to be(false)
      expect(Doorkeeper::AccessToken.exists?(live_access_token.id)).to be(true)
    end

    it "keeps them when the refresh_token_revoked_at column is absent" do
      token = FactoryBot.create(
        :access_token, expires_in: 1, created_at: 10.days.ago, use_refresh_token: true,
      )
      token.update_column(:refresh_token_revoked_at, 9.days.ago)
      allow(Doorkeeper::AccessToken).to receive(:refresh_token_revoked_at_supported?).and_return(false)

      task = Rake::Task["doorkeeper:db:cleanup:expired_tokens"]
      task.reenable
      task.invoke

      expect(Doorkeeper::AccessToken.exists?(token.id)).to be(true)
    end
  end
end
