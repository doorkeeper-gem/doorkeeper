# frozen_string_literal: true

class AddRefreshTokenScopesToAccessTokens < ActiveRecord::Migration[6.1]
  def change
    add_column :oauth_access_tokens, :refresh_token_scopes, :string
  end
end
