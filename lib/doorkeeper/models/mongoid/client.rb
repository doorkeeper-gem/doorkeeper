module Doorkeeper
  module Models
    module Mongoid
      module Client
        extend ActiveSupport::Concern

        included do
          has_many :authorized_tokens, :class_name => "Doorkeeper::AccessToken"
          has_many :access_grants, :dependent => :destroy, :class_name => "Doorkeeper::AccessGrant", :foreign_key => 'application_id'
          has_many :access_tokens, :dependent => :destroy, :class_name => "Doorkeeper::AccessToken", :foreign_key => 'application_id'
        end

        module ClassMethods
          def authorized_for(resource_owner)
            ids = AccessToken.where(:resource_owner_id => resource_owner.id, :revoked_at => nil).map(&:application_id)
            find(ids)
          end
        end
      end
    end
  end
end
