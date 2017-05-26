# frozen_string_literal: true
module Doorkeeper
  module Models
    module DatabaseAuthenticatable
      extend ActiveSupport::Concern

      included do
        has_secure_password
      end
    end
  end
end
