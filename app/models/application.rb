class Application < ActiveRecord::Base
  include Doorkeeper::OAuth::RandomString
  set_table_name 'oauth_applications'

  has_many :access_grants

  validates :name, :secret, :presence => true
  validates :uid, :presence => true, :uniqueness => true

  before_validation :generate_uid, :generate_secret, :on => :create

  private
  def generate_uid
    self.uid = unique_random_string_for(:uid)
  end

  def generate_secret
    self.secret = random_string
  end
end
