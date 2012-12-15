module Doorkeeper
  module Models
    module Mongoid2
      module Client
        extend ActiveSupport::Concern

        included do
          has_many :authorized_tokens, :class_name => "Doorkeeper::AccessToken"

          index :uid, :unique => true
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
