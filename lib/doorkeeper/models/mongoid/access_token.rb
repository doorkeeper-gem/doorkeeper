module Doorkeeper
  class AccessToken
    include Mongoid::Document
    include Mongoid::Timestamps

    self.store_in :oauth_access_tokens

    field :resource_owner_id, :type => Integer
    field :token, :type => String
    field :expires_in, :type => Integer
    field :revoked_at, :type => DateTime

    index :token, :unique => true
    index :refresh_token, :unique => true, :sparse => true

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

    def scopes=(value)
      write_attribute :scopes, value
    end
  end
end
