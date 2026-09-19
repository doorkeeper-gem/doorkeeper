# frozen_string_literal: true

class AddRefreshTokenFamilyIdToAccessTokens < ActiveRecord::Migration[6.1]
  def change
    add_column :oauth_access_tokens, :refresh_token_family_id, :string
    add_index :oauth_access_tokens, :refresh_token_family_id
  end
end
