require 'doorkeeper/orm/mongoid2/concerns/scopes'

module Doorkeeper
  class AccessToken
    include Mongoid::Document
    include Mongoid::Timestamps

    include AccessTokenMixin
    include Models::Mongoid2::Scopes

    self.store_in :oauth_access_tokens

    field :resource_owner_id, type: Integer
    field :application_id, type: BSON::ObjectId
    field :token, type: String
    field :refresh_token, type: String
    field :expires_in, type: Integer
    field :revoked_at, type: DateTime

    index :token, unique: true
    index :refresh_token, unique: true, sparse: true

    def self.delete_all_for(application_id, resource_owner)
      where(application_id: application_id,
            resource_owner_id: resource_owner.id).delete_all
    end
    private_class_method :delete_all_for

    def self.order_method
      :order_by
    end
    def self.created_at_desc
      [:created_at, :desc]
    end
  end
end
