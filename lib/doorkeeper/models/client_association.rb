module Doorkeeper
  module Models
    module ClientAssociation
      extend ActiveSupport::Concern

      included do
        belongs_to :application, :class_name => "::#{Doorkeeper.client}", :foreign_key => 'application_id'
      end
    end
  end
end
