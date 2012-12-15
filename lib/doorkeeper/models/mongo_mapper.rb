module DoorkeeperClient
  extend ActiveSupport::Concern

  included do
    include Doorkeeper::Models::Registerable
    include Doorkeeper::Models::Authenticatable

    Doorkeeper.client = self
    Doorkeeper::AccessToken.send :include, DoorkeeperClient::Association
    Doorkeeper::AccessGrant.send :include, DoorkeeperClient::Association

    many :authorized_tokens, :class_name => "Doorkeeper::AccessToken"

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

  module Association
    extend ActiveSupport::Concern

    included do
      belongs_to :application, :class_name => "::#{Doorkeeper.client}", :foreign_key => 'application_id'
    end
  end
end
