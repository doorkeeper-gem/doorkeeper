require 'doorkeeper/models/mongoid/revocable'
require 'doorkeeper/models/mongoid/scopes'
require 'doorkeeper/models/mongoid/version_check'

module Doorkeeper
  class AccessToken
    include Mongoid::Document
    include Mongoid::Timestamps
    include Doorkeeper::Models::Mongoid::Revocable
    include Doorkeeper::Models::Mongoid::Scopes
    include Doorkeeper::Models::Mongoid::VersionCheck

    if is_mongoid_3_x?
      self.store_in collection: :oauth_access_tokens

      field :resource_owner_id, :type => Moped::BSON::ObjectId
    else
      self.store_in :oauth_access_tokens

      field :resource_owner_id, :type => Integer
    end

    field :token, :type => String
    field :expires_in, :type => Integer
    field :revoked_at, :type => DateTime

    if is_mongoid_3_x?
      index({ token: 1 }, { unique: true })
      index({ refresh_token: 1 }, { unique: true, sparse: true })
    else
      index :token, :unique => true
      index :refresh_token, :unique => true, :sparse => true
    end

    def self.last_authorized_token_for(application, resource_owner_id)
      where(:application_id => application.id,
            :resource_owner_id => resource_owner_id,
            :revoked_at => nil).
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
