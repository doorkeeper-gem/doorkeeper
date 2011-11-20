class AccessToken < ActiveRecord::Base
  include Doorkeeper::OAuth::RandomString

  self.table_name = "oauth_access_tokens"

  belongs_to :application

  scope :accessible, where(:revoked_at => nil)

  validates :application_id, :resource_owner_id, :presence => true

  before_validation :generate_token, :on => :create

  def revoke!
    update_attribute :revoked_at, DateTime.now
  end

  def revoked?
    self.revoked_at.present?
  end

  def expired?
    self.expires_at.present? && DateTime.now > self.expires_at
  end

  def accessible?
    !expired? && !revoked?
  end

  private

  def generate_token
    self.token = unique_random_string_for(:token)
  end
end
