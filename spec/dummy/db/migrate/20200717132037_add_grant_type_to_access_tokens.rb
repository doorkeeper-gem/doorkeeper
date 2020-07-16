# frozen_string_literal: true

class AddGrantTypeToAccessTokens < ActiveRecord::Migration[6.0]
  def change
    add_column(
      :oauth_access_tokens,
      :grant_type,
      :string,
      null: true,
    )
  end
end
