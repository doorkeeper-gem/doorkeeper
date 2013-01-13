class User < ActiveRecord::Base
  attr_accessible :name, :password

  def self.authenticate!(name, password)
    User.where(:name => name, :password => password).first
  end
end
