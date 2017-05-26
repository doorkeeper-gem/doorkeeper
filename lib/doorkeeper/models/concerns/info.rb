# frozen_string_literal: true
module Doorkeeper
  module Models
    module Info
      extend ActiveSupport::Concern

      included do
        validates :full_name,
                  presence: true

        validates :email,
                  presence: true,
                  uniqueness: true,
                  format: /\A[\w+\-.]+@[a-z\-.]+\.[a-z]+\z/i
      end
    end
  end
end
