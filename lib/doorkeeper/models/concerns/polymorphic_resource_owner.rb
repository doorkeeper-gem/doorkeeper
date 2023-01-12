# frozen_string_literal: true

module Doorkeeper
  module Models
    module PolymorphicResourceOwner
      module ForAccessGrant
        extend ActiveSupport::Concern

        included do
          if Doorkeeper.config.polymorphic_resource_owner?
            belongs_to :resource_owner, polymorphic: true, optional: false
          else
            validates :resource_owner_id, presence: true
          end
        end
      end

      module ForAccessToken
        extend ActiveSupport::Concern

        included do
          if Doorkeeper.config.polymorphic_resource_owner?
            belongs_to :resource_owner, polymorphic: true, optional: true
          end
        end
      end
    end
  end
end

