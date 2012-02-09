class Application < ActiveRecord::Base
  include Doorkeeper::OAuth::Helpers

  self.table_name = :oauth_applications

  has_many :access_grants
  has_many :authorized_tokens, :class_name => "AccessToken", :conditions => { :revoked_at => nil }
  has_many :authorized_applications, :through => :authorized_tokens, :source => :application

  validates :name, :secret, :redirect_uri, :presence => true
  validates :uid, :presence => true, :uniqueness => true
  validate :validate_redirect_uri

  before_validation :generate_uid, :generate_secret, :on => :create

  def self.column_names_with_table
    self.column_names.map { |c| "oauth_applications.#{c}" }
  end

  def self.authorized_for(resource_owner)
    joins(:authorized_applications).
      where(:oauth_access_tokens => { :resource_owner_id => resource_owner.id }).
      group(column_names_with_table.join(','))
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

  private

  def generate_uid
    self.uid = UniqueToken.generate_for :uid, self.class
  end

  def generate_secret
    self.secret = UniqueToken.generate_for :secret, self.class
  end
end
