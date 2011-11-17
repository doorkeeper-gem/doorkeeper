class AccessGrant < ActiveRecord::Base
  include OAuth::RandomString

  self.table_name = "oauth_access_grants"

  belongs_to :application

  validates :resource_owner_id, :application_id, :token, :expires_in, :presence => true

  before_validation :generate_token, :on => :create

  def expired?
    expires_in.present? && Time.now > expired_time
  end

  def accessible?
    !expired?
  end

  private

  def expired_time
    self.created_at + expires_in.seconds
  end

  def generate_token
    self.token = unique_random_string_for(:token)
  end
end
