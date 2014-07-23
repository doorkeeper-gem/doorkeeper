require 'doorkeeper/models/mongoid/scopes'

module Doorkeeper
  class AccessGrant
    include Mongoid::Document
    include Mongoid::Timestamps
    include Models::Mongoid::Scopes

    self.store_in :oauth_access_grants

    field :resource_owner_id, type: Integer
    field :application_id, type: Hash
    field :token, type: String
    field :expires_in, type: Integer
    field :redirect_uri, type: String
    field :revoked_at, type: DateTime

    index :token, unique: true
  end
end
