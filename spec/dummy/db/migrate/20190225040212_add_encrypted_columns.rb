# frozen_string_literal: true

class AddEncryptedColumns < ActiveRecord::Migration[5.2]
  def change
    add_column :oauth_applications, :encrypted_secret, :binary

    add_column :oauth_access_tokens, :encrypted_token, :binary
    add_column :oauth_access_tokens, :encrypted_refresh_token, :binary

    add_column :oauth_access_grants, :encrypted_token, :binary
  end
end
