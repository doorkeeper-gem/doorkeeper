module Doorkeeper
  class Application
    include Mongoid::Document
    include Mongoid::Timestamps

    self.store_in collection: :oauth_applications

    field :name, type: String
    field :uid, type: String
    field :secret, type: String
    field :redirect_uri, type: String

    index({ uid: 1 }, { unique: true })

    has_many :authorized_tokens, class_name: 'Doorkeeper::AccessToken'

    def self.resource_owner_property
      Doorkeeper.configuration.resource_owner_property
    end
    private_class_method :resource_owner_property

    def self.authorized_for(resource_owner)
      ids = AccessToken.where(resource_owner_uid: resource_owner.send(resource_owner_property), revoked_at: nil).map(&:application_id)
      find(ids)
    end
  end
end
