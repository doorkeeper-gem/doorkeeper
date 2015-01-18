class AddPreviousRefreshTokenToAccessTokens < ActiveRecord::Migration
  def change
    add_column :oauth_access_tokens, :previous_refresh_token, :string
  end
end
