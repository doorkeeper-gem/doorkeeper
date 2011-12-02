class AccessToken < ActiveRecord::Base
  include Doorkeeper::OAuth::RandomString

  set_table_name :oauth_access_tokens

  belongs_to :application

  scope :accessible, where(:revoked_at => nil)

  validates :application_id, :resource_owner_id, :token, :presence => true

  before_validation :generate_token, :on => :create

  def self.authorized_for(application_id, resource_owner_id)
    accessible.where(:application_id => application_id, :resource_owner_id => resource_owner_id).first
  end

  def revoke
    update_attribute :revoked_at, DateTime.now
  end

  def revoked?
    self.revoked_at.present?
  end

  def expired?
    expires_in.present? && Time.now > expired_time
  end

  def accessible?
    !expired? && !revoked?
  end

  def scopes
    self[:scopes].split(" ").map(&:to_sym)
  end

  private

  def expired_time
    self.created_at + expires_in.seconds
  end

  def generate_token
    self.token = unique_random_string_for(:token)
  end
end
