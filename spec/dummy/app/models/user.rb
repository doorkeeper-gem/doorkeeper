if defined? ActiveRecord
  class User < ActiveRecord::Base
  end
end

if defined? Mongoid
  class User
    include Mongoid::Document
    include Mongoid::Timestamps

    field :name, :type => String
    field :password, :type => String
  end
end

class User
  attr_accessible :name, :password

  def self.authenticate!(name, password)
    User.where(:name => name, :password => password).first
  end
end
