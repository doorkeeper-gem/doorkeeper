# frozen_string_literal: true

class AddCustomAttributes < ActiveRecord::Migration[4.2]
  def change
    add_column :oauth_access_grants, :tenant_name, :string
    add_column :oauth_access_tokens, :tenant_name, :string
  end
end
