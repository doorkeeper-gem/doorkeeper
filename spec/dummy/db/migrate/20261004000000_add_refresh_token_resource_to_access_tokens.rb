# frozen_string_literal: true

class AddRefreshTokenResourceToAccessTokens < ActiveRecord::Migration[6.1]
  def change
    add_column :oauth_access_tokens, :refresh_token_resource, :text
  end
end
