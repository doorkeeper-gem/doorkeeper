class User < ActiveRecord::Base
  if ::Rails.version.to_i < 4
    attr_accessible :name, :password
  end

  def self.authenticate!(name, password)
    User.where(name: name, password: password).first
  end
end