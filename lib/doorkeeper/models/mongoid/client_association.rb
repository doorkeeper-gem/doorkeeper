module Doorkeeper
  module Models
    module Mongoid
      module ClientAssociation
        extend ActiveSupport::Concern

        included do
          belongs_to :application,
                     :class_name => "::#{Doorkeeper.client}",
                     :foreign_key => 'application_id',
                     :inverse_of => :application
        end
      end
    end
  end
end
