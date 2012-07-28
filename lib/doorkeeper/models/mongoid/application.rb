require 'doorkeeper/models/mongoid/version_check'

module Doorkeeper
  class Application
    include Mongoid::Document
    include Mongoid::Timestamps
    include Doorkeeper::Models::Mongoid::VersionCheck

    has_many :authorized_tokens, :class_name => "Doorkeeper::AccessToken"

    field :name, :type => String
    field :uid, :type => String
    field :secret, :type => String
    field :redirect_uri, :type => String

    if is_mongoid_3_x?
      self.store_in collection: :oauth_applications
      index({ uid: 1 }, { unique: true })
    else
      self.store_in :oauth_applications

      index :uid, :unique => true
    end

    def self.authorized_for(resource_owner)
      ids = AccessToken.where(:resource_owner_id => resource_owner.id, :revoked_at => nil).map(&:application_id)
      find(ids)
    end
  end
end
