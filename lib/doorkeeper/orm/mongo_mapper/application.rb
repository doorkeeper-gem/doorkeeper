module Doorkeeper
  class Application
    include MongoMapper::Document

    include ApplicationMixin

    safe
    timestamps!

    set_collection_name 'oauth_applications'

    many :authorized_tokens, class_name: 'Doorkeeper::AccessToken'

    key :name,         String
    key :uid,          String
    key :secret,       String
    key :redirect_uri, String
    key :scopes,       String

    def self.authorized_for(resource_owner)
      ids = AccessToken.where(resource_owner_id: resource_owner.id, revoked_at: nil).map(&:application_id)
      find(ids)
    end

    def self.create_indexes
      ensure_index :uid, unique: true
    end
  end
end
