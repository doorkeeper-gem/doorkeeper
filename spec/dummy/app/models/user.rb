class User < ActiveRecord::Base
  has_secure_password
  validates_presence_of :password, :on => :create

  attr_accessible :name, :password

  def self.authenticate!(name, password)
    owner = User.find_by_name(name)
    owner.authenticate(password) if owner
  end
end
