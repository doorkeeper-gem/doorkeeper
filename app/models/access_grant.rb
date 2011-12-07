class AccessGrant < ActiveRecord::Base
  include Doorkeeper::OAuth::RandomString

  set_table_name :oauth_access_grants

  belongs_to :application

  validates :resource_owner_id, :application_id, :token, :expires_in, :redirect_uri, :presence => true

  before_validation :generate_token, :on => :create

  def expired?
    expires_in.present? && Time.now > expired_time
  end

  def accessible?
    !expired? && !revoked?
  end

  def revoke
    update_attribute :revoked_at, DateTime.now
  end

  def revoked?
    revoked_at.present?
  end

  def scopes
    self[:scopes].split(" ").map(&:to_sym)
  end

  def scopes_string
    self[:scopes]
  end

  private

  def expired_time
    self.created_at + expires_in.seconds
  end

  def generate_token
    self.token = unique_random_string_for(:token)
  end
end
