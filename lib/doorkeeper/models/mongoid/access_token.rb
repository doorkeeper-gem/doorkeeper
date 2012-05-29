module Doorkeeper
  class AccessToken
    include Mongoid::Document
    include Mongoid::Timestamps

    store_in = :oauth_access_tokens

    field :resource_owner_id, :type => Integer
    field :token, :type => String
    field :expires_in, :type => Integer
    field :revoked_at, :type => DateTime
    field :scopes, :type => Array

    index :token, :unique => true
    index :refresh_token, :unique => true, :sparse => true

    def refresh_token
      self[:refresh_token]
    end

    def self.find_by_refresh_token(refresh_token)
      where(:refresh_token => refresh_token).first
    end
  end
end
