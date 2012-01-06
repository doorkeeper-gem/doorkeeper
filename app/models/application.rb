class Application < ActiveRecord::Base
  include Doorkeeper::OAuth::RandomString

  set_table_name :oauth_applications

  has_many :access_grants
  has_many :authorized_tokens, :class_name => "AccessToken", :conditions => { :revoked_at => nil }
  has_many :authorized_applications, :through => :authorized_tokens, :source => :application

  validates :name, :secret, :redirect_uri, :presence => true
  validates :uid, :presence => true, :uniqueness => true
  validate :validate_redirect_uri

  before_validation :generate_uid, :generate_secret, :on => :create

  def self.authorized_for(resource_owner)
    joins(:authorized_applications).where(:oauth_access_tokens => { :resource_owner_id => resource_owner.id })
  end

  def validate_redirect_uri
    return unless redirect_uri
    uri = URI.parse(redirect_uri)
    errors.add(:redirect_uri, "cannot contain a fragment.") unless uri.fragment.nil?
    errors.add(:redirect_uri, "must be an absolute URL.") if uri.scheme.nil? || uri.host.nil?
    errors.add(:redirect_uri, "cannot contain a query parameter.") unless uri.query.nil?
  rescue URI::InvalidURIError => e
    errors.add(:redirect_uri, "must be a valid URI.")
  end

  def is_matching_redirect_uri?(uri_string)
    uri = URI.parse(uri_string)
    uri.query = nil
    uri.to_s == redirect_uri
  end

  private
  def generate_uid
    self.uid = unique_random_string_for(:uid)
  end

  def generate_secret
    self.secret = random_string
  end
end
