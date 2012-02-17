module Doorkeeper
  class AccessToken < ActiveRecord::Base
    include Doorkeeper::OAuth::Helpers
    include Doorkeeper::Models::Expirable
    include Doorkeeper::Models::Revocable

    self.table_name = :oauth_access_tokens

    belongs_to :application

    scope :accessible, where(:revoked_at => nil)

    validates :application_id, :resource_owner_id, :token, :presence => true

    attr_accessor :use_refresh_token

    before_validation :generate_token, :on => :create
    before_validation :generate_refresh_token, :on => :create, :if => :use_refresh_token?

    def self.revoke_all_for(application_id, resource_owner)
      where(:application_id => application_id,
              :resource_owner_id => resource_owner.id).delete_all
    end

    def self.matching_token_for(application, resource_owner_or_id, scopes)
      token = last_authorized_token_for(application, resource_owner_or_id)
      token if token && ScopeChecker.matches?(token.scopes, scopes)
    end

    def self.last_authorized_token_for(application, resource_owner_or_id)
      resource_owner_id = resource_owner_or_id.kind_of?(ActiveRecord::Base) ? resource_owner_or_id.id : resource_owner_or_id
      accessible.
        where(:application_id => application.id,
              :resource_owner_id => resource_owner_id).
        order("created_at desc").
        limit(1).
        first
    end
    private_class_method :last_authorized_token_for

    def token_type
      "bearer"
    end

    def accessible?
      !expired? && !revoked?
    end

    def scopes
      scope_string = self[:scopes] || ""
      scope_string.split(" ").map(&:to_sym)
    end

    def scopes_string
      self[:scopes]
    end

    def use_refresh_token?
      self.use_refresh_token
    end

    private

    def generate_refresh_token
      self.refresh_token = UniqueToken.generate_for :refresh_token, self.class
    end

    def generate_token
      self.token = UniqueToken.generate_for :token, self.class
    end
  end
end
