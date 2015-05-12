class User < ActiveRecord::Base
  if respond_to?(:attr_accessible)
    attr_accessible :name, :password
  end

  def self.authenticate!(name, password)
    User.where(name: name, password: password).first
  end
end
