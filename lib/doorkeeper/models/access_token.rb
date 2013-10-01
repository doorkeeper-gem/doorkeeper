module Doorkeeper
  class AccessToken
    include Doorkeeper::OAuth::Helpers
    include Doorkeeper::Models::Expirable
    include Doorkeeper::Models::Revocable
    include Doorkeeper::Models::Accessible
    include Doorkeeper::Models::Scopes

    belongs_to :application, :class_name => "Doorkeeper::Application", :inverse_of => :access_tokens

    validates :application_id, :token, :presence => true
    validates :token, :uniqueness => true
    validates :refresh_token, :uniqueness => true, :if => :use_refresh_token?

    attr_accessor :use_refresh_token
    if ::Rails.version.to_i < 4 || defined?(ProtectedAttributes)
      attr_accessible :application_id, :resource_owner_id, :expires_in, :scopes, :use_refresh_token
    end

    before_validation :generate_token, :on => :create
    before_validation :generate_refresh_token, :on => :create, :if => :use_refresh_token?

    def self.authenticate(token)
      where(:token => token).first
    end

    def self.by_refresh_token(refresh_token)
      where(:refresh_token => refresh_token).first
    end

    def self.revoke_all_for(application_id, resource_owner)
      delete_all_for(application_id, resource_owner)
    end

    def self.matching_token_for(application, resource_owner_or_id, scopes)
      resource_owner_id = resource_owner_or_id.respond_to?(:to_key) ? resource_owner_or_id.id : resource_owner_or_id
      token = last_authorized_token_for(application, resource_owner_id)
      token if token && ScopeChecker.matches?(token.scopes, scopes)
    end

    def token_type
      "bearer"
    end

    def use_refresh_token?
      self.use_refresh_token
    end

    def as_json(options={})
      {
        :resource_owner_id => self.resource_owner_id,
        :scopes => self.scopes,
        :expires_in_seconds => self.expires_in_seconds,
        :application => { :uid => self.application.uid }
      }
    end

    private

    def generate_refresh_token
      write_attribute :refresh_token, UniqueToken.generate
    end

    def generate_token
      self.token = UniqueToken.generate
    end

  end
end
