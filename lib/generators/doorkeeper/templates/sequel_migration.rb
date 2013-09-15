Sequel.migration do
  change do

    create_table :oauth_applications do
      primary_key :id
      String  :name,         null: false
      String  :uid,          null: false
      String  :secret,       null: false
      String  :redirect_uri, null: false
      DateTime :created_at, null: false
      DateTime :updated_at

      index :uid, unique: true
    end

    create_table :oauth_access_grants do
      primary_key :id
      Integer  :resource_owner_id, null: false
      Integer  :application_id,    null: false
      String   :token,             null: false
      Integer  :expires_in,        null: false
      String   :redirect_uri,      null: false
      DateTime :created_at,        null: false
      DateTime :updated_at
      DateTime :revoked_at
      String   :scopes

      index :token, unique: true
    end

    create_table :oauth_access_tokens do
      primary_key :id
      Integer  :resource_owner_id
      Integer  :application_id,    null: false
      String   :token,             null: false
      String   :refresh_token
      Integer  :expires_in
      DateTime :revoked_at
      DateTime :created_at,        null: false
      DateTime :updated_at
      String   :scopes

      index :token, unique: true
      index :resource_owner_id
      index :refresh_token, unique: true
    end
  end
end
