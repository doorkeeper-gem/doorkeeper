class Application < ActiveRecord::Base
  include Doorkeeper::OAuth::RandomString

  self.table_name = :oauth_applications

  has_many :access_grants
  has_many :authorized_tokens, :class_name => "AccessToken", :conditions => { :revoked_at => nil }
  has_many :authorized_applications, :through => :authorized_tokens, :source => :application

  validates :name, :secret, :redirect_uri, :presence => true
  validates :uid, :presence => true, :uniqueness => true

  before_validation :generate_uid, :generate_secret, :on => :create

  def self.authorized_for(resource_owner)
    joins(:authorized_applications).where(:oauth_access_tokens => { :resource_owner_id => resource_owner.id })
  end

  private
  def generate_uid
    self.uid = unique_random_string_for(:uid)
  end

  def generate_secret
    self.secret = random_string
  end
end
