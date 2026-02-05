# frozen_string_literal: true

class EnableDpop < ActiveRecord::Migration[5.0]
  def change
    add_column :oauth_access_tokens, :dpop_jkt, :string, null: true
  end
end
