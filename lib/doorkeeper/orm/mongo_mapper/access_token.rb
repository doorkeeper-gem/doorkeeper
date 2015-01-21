module Doorkeeper
  class AccessToken
    include MongoMapper::Document

    include AccessTokenMixin

    safe
    timestamps!

    set_collection_name 'oauth_access_tokens'

    key :resource_owner_id, ObjectId
    key :application_id,    ObjectId
    key :token,             String
    key :refresh_token,     String
    key :expires_in,        Integer
    key :revoked_at,        DateTime
    key :scopes,            String
    key :previous_refresh_token, String

    def self.last
      self.sort(:created_at).last
    end

    def self.delete_all_for(application_id, resource_owner)
      delete_all(application_id: application_id,
                 resource_owner_id: resource_owner.id)
    end
    private_class_method :delete_all_for

    def self.create_indexes
      ensure_index :token, unique: true
      ensure_index [[:refresh_token, 1]], unique: true, sparse: true
    end

    def self.order_method
      :sort
    end

    def self.created_at_desc
      :created_at.desc
    end
  end
end
