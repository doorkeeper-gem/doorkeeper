require 'doorkeeper/models/mongoid/revocable'
require 'doorkeeper/models/mongoid/scopes'
require 'doorkeeper/models/mongoid/version_check'

module Doorkeeper
  class AccessGrant
    include Mongoid::Document
    include Mongoid::Timestamps
    include Doorkeeper::Models::Mongoid::Revocable
    include Doorkeeper::Models::Mongoid::Scopes
    include Doorkeeper::Models::Mongoid::VersionCheck


    if is_mongoid_3_x?
      self.store_in collection: :oauth_access_grants

      field :resource_owner_id, :type => Moped::BSON::ObjectId
    else
      self.store_in :oauth_access_grants

      field :resource_owner_id, :type => Integer
    end

    field :application_id, :type => Hash
    field :token, :type => String
    field :expires_in, :type => Integer
    field :redirect_uri, :type => String
    field :revoked_at, :type => DateTime

    if is_mongoid_3_x?
      index({ token: 1 }, { unique: true })
    else
      index :token, :unique => true
    end
  end
end
