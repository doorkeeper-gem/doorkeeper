class AddStrategyUsedToAccessToken < ActiveRecord::Migration[5.2]
  def change
    add_column(
      :oauth_access_tokens,
      :strategy_used,
      :string,
      null: true
    )
  end
end
