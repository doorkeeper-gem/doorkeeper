module Doorkeeper
  class AccessToken
    include MongoMapper::Document
    safe
    timestamps!

    set_collection_name 'oauth_access_tokens'

    key :resource_owner_id, ObjectId
    key :token,             String
    key :expires_in,        Integer
    key :revoked_at,        DateTime
    key :scopes,            String

    def scopes=(value)
      write_attribute :scopes, value if value.present?
    end

    def self.last
      self.sort(:created_at).last
    end

    def self.delete_all_for(application_id, resource_owner)
      delete_all(application_id: application_id,
                 resource_owner_id: resource_owner.id)
    end
    private_class_method :delete_all_for

    def self.last_authorized_token_for(application_id, resource_owner_id)
      where(application_id: application_id,
            resource_owner_id: resource_owner_id,
            revoked_at: nil).
        sort(:created_at.desc).
        limit(1).
        first
    end
    private_class_method :last_authorized_token_for

    def refresh_token
      self[:refresh_token]
    end

    def self.create_indexes
      ensure_index :token, unique: true
      ensure_index [[:refresh_token, 1]], unique: true, sparse: true
    end
  end
end
