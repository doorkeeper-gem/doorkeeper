module Doorkeeper
  class Application < ActiveRecord::Base
    self.table_name = :oauth_applications

    has_many :authorized_tokens, :class_name => "AccessToken", :conditions => { :revoked_at => nil }
    has_many :authorized_applications, :through => :authorized_tokens, :source => :application
  end
end
