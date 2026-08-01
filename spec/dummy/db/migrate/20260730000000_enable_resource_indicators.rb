# frozen_string_literal: true

class EnableResourceIndicators < ActiveRecord::Migration[5.0]
  def change
    add_column :oauth_access_grants, :resource, :text, null: true
    add_column :oauth_access_tokens, :resource, :text, null: true
  end
end
