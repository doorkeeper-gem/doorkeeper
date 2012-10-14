case DOORKEEPER_ORM
when :active_record
  class User < ActiveRecord::Base
  end
when :mongoid
  class User
    include Mongoid::Document
    include Mongoid::Timestamps

    field :name, :type => String
    field :password, :type => String
  end
when :mongo_mapper
  class User
    include MongoMapper::Document
    timestamps!

    key :name,     String
    key :password, String
  end
end

class User
  attr_accessible :name, :password

  def self.authenticate!(name, password)
    User.where(:name => name, :password => password).first
  end
end
