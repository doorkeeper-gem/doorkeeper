module DoorkeeperClient
  extend ActiveSupport::Concern

  included do
    include Doorkeeper::Models::Registerable
    include Doorkeeper::Models::Authenticatable

    Doorkeeper.client = self
    Doorkeeper::AccessToken.send :include, Doorkeeper::Models::ClientAssociation
    Doorkeeper::AccessGrant.send :include, Doorkeeper::Models::ClientAssociation

    many :authorized_tokens, :class_name => "Doorkeeper::AccessToken"

    many :access_grants,
         :dependent => :destroy,
         :class_name => "Doorkeeper::AccessGrant",
         :foreign_key => 'application_id'

    many :access_tokens,
         :dependent => :destroy,
         :class_name => "Doorkeeper::AccessToken",
         :foreign_key => 'application_id'

    ensure_index :uid, :unique => true
  end

  module ClassMethods
    def authorized_for(resource_owner)
      ids = Doorkeeper::AccessToken.where(:resource_owner_id => resource_owner.id, :revoked_at => nil).map(&:application_id)
      find(ids)
    end

    def create_indexes
      ensure_index :uid, :unique => true
    end
  end
end
