class AccessToken < ActiveRecord::Base
  include Doorkeeper::OAuth::RandomString
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

  def self.authorized_for(application_id, resource_owner_id)
    accessible.where(:application_id => application_id, :resource_owner_id => resource_owner_id).first
  end

  def self.has_authorized_token_for?(application, resource_owner, scopes)
    token = accessible.
            where(:application_id => application.id,
                  :resource_owner_id => resource_owner.id).
            order("created_at desc").
            limit(1).
            first
    token && ScopeChecker.matches?(token.scopes, scopes)
  end

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
    self.refresh_token = unique_random_string_for(:refresh_token)
  end

  def generate_token
    self.token = unique_random_string_for(:token)
  end
end
