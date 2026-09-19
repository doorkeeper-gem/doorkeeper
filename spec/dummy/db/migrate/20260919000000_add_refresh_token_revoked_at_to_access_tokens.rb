# frozen_string_literal: true

class AddRefreshTokenRevokedAtToAccessTokens < ActiveRecord::Migration[6.1]
  def change
    add_column :oauth_access_tokens, :refresh_token_revoked_at, :datetime
  end
end
