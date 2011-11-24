class CreateDoorkeeperTables < ActiveRecord::Migration
  def change
    create_table :oauth_applications do |t|
      t.string :name,         :null => false
      t.string :uid,          :null => false
      t.string :secret,       :null => false
      t.string :redirect_uri, :null => false
      t.timestamps
    end

    create_table :oauth_access_grants do |t|
      t.integer  :resource_owner_id, :null => false
      t.integer  :application_id,    :null => false
      t.string   :token,             :null => false
      t.integer  :expires_in,        :null => false
      t.string   :redirect_uri,      :null => false
      t.datetime :created_at,        :null => false
    end

    create_table :oauth_access_tokens do |t|
      t.integer  :resource_owner_id, :null => false
      t.integer  :application_id,    :null => false
      t.string   :token,             :null => false
      t.datetime :expires_at
      t.datetime :revoked_at
      t.datetime :created_at,        :null => false
    end
  end
end
