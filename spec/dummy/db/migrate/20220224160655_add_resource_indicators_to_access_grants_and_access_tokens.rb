# frozen_string_literal: true

class AddResourceIndicatorsToAccessGrantsAndAccessTokens < ActiveRecord::Migration[7.0]
  def change
    add_column(
      :oauth_access_grants,
      :resource_indicators,
      :string,
      null: true,
    )

    add_column(
      :oauth_access_tokens,
      :resource_indicators,
      :string,
      null: true,
    )
  end
end
