module Doorkeeper
  class AccessGrant
    include MongoMapper::Document
    safe
    timestamps!

    set_collection_name 'oauth_access_grants'

    key :resource_owner_id, ObjectId
    key :application_id,    ObjectId
    key :token,             String
    key :expires_in,        Integer
    key :redirect_uri,      String
    key :revoked_at,        DateTime
    key :scopes,            String

    def scopes=(value)
      write_attribute :scopes, value if value.present?
    end

    def self.create_indexes
      ensure_index :token, unique: true
    end
  end
end
