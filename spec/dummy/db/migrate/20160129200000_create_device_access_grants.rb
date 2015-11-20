class CreateDeviceAccessGrants < ActiveRecord::Migration
  def change
    create_table :oauth_device_access_grants do |t|
      t.integer  :application_id,    null: false
      t.string   :token,             null: false
      t.string   :user_token,        null: false
      t.integer  :expires_in,        null: false
      t.datetime :created_at,        null: false
      t.datetime :revoked_at
      t.string   :scopes
    end

    add_index :oauth_device_access_grants, :token, unique: true
    add_index :oauth_device_access_grants, :user_token, unique: true
  end
end
