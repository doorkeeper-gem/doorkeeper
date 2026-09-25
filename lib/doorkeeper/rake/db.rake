# frozen_string_literal: true

namespace :doorkeeper do
  namespace :db do
    desc "Removes stale data from doorkeeper related database tables"
    task cleanup: [
      "doorkeeper:db:cleanup:revoked_tokens",
      "doorkeeper:db:cleanup:expired_tokens",
      "doorkeeper:db:cleanup:revoked_grants",
      "doorkeeper:db:cleanup:expired_grants",
    ]

    namespace :cleanup do
      desc "Removes stale access tokens"
      task revoked_tokens: "doorkeeper:setup" do
        cleaner = Doorkeeper::StaleRecordsCleaner.new(Doorkeeper.config.access_token_model)
        cleaner.clean_revoked
      end

      desc "Removes expired (TTL passed) access tokens"
      task expired_tokens: "doorkeeper:setup" do
        access_token_model = Doorkeeper.config.access_token_model
        expirable_tokens = access_token_model.where(refresh_token: nil)

        # A refresh token revoked on its own
        # (+revoke_previous_access_token_on_refresh false+) leaves +revoked_at+
        # empty, so the revoked_tokens task never sees the record: once its
        # access token expires nothing on it can be used anymore.
        if access_token_model.try(:refresh_token_revoked_at_supported?)
          refresh_token_revoked_at = access_token_model.arel_table[:refresh_token_revoked_at]
          expirable_tokens = expirable_tokens.or(
            access_token_model.where(refresh_token_revoked_at.lt(Time.current)),
          )
        end

        cleaner = Doorkeeper::StaleRecordsCleaner.new(expirable_tokens)
        cleaner.clean_expired(Doorkeeper.config.access_token_expires_in)
      end

      desc "Removes stale access grants"
      task revoked_grants: "doorkeeper:setup" do
        cleaner = Doorkeeper::StaleRecordsCleaner.new(Doorkeeper.config.access_grant_model)
        cleaner.clean_revoked
      end

      desc "Removes expired (TTL passed) access grants"
      task expired_grants: "doorkeeper:setup" do
        cleaner = Doorkeeper::StaleRecordsCleaner.new(Doorkeeper.config.access_grant_model)
        cleaner.clean_expired(Doorkeeper.config.authorization_code_expires_in)
      end
    end
  end
end
