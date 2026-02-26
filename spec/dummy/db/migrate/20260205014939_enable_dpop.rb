# frozen_string_literal: true

class EnableDpop < ActiveRecord::Migration[8.0]
  def change
    add_column :oauth_access_tokens, :dpop_jkt, :string, null: true
    add_index :oauth_access_tokens, :dpop_jkt
  end
end
