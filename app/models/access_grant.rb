class AccessGrant < ActiveRecord::Base
  include Doorkeeper::OAuth::Helpers
  include Doorkeeper::Models::Expirable
  include Doorkeeper::Models::Revocable

  self.table_name = :oauth_access_grants

  belongs_to :application

  validates :resource_owner_id, :application_id, :token, :expires_in, :redirect_uri, :presence => true

  before_validation :generate_token, :on => :create

  def accessible?
    !expired? && !revoked?
  end

  def scopes
    self[:scopes].split(" ").map(&:to_sym)
  end

  def scopes_string
    self[:scopes]
  end

  private

  def generate_token
    self.token = UniqueToken.generate_for :token, self.class
  end
end
