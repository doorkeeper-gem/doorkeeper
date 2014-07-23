require 'doorkeeper/models/mongoid/scopes'
require 'doorkeeper/models/mongoid/version'

module Doorkeeper
  class AccessToken
    include Mongoid::Document
    include Mongoid::Timestamps
    include Models::Mongoid::Scopes
    extend Models::Mongoid::Version

    self.store_in collection: :oauth_access_tokens

    if defined?(Moped::BSON)
      field :resource_owner_id, type: Moped::BSON::ObjectId
    else
      field :resource_owner_id, type: BSON::ObjectId
    end

    field :token, type: String
    field :expires_in, type: Integer
    field :revoked_at, type: DateTime

    index({ token: 1 }, { unique: true })
    index({ refresh_token: 1 }, { unique: true, sparse: true })

    def self.delete_all_for(application_id, resource_owner)
      where(application_id: application_id,
            resource_owner_id: resource_owner.id).delete_all
    end
    private_class_method :delete_all_for

    def self.last_authorized_token_for(application_id, resource_owner_id)
      where(application_id: application_id,
            resource_owner_id: resource_owner_id,
            revoked_at: nil).
        order_by([:created_at, :desc]).
        limit(1).
        first
    end
    private_class_method :last_authorized_token_for

    def refresh_token
      self[:refresh_token]
    end
  end
end
