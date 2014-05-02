case DOORKEEPER_ORM
when :active_record
  class User < ActiveRecord::Base
  end
when :mongoid2, :mongoid3, :mongoid4
  class User
    include Mongoid::Document
    include Mongoid::Timestamps

    field :name, type: String
    field :password, type: String
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
  if ::Rails.version.to_i < 4
    attr_accessible :name, :password
  end

  def self.authenticate!(name, password)
    User.where(name: name, password: password).first
  end
end
