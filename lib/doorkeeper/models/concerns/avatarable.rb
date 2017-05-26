# frozen_string_literal: true
module Doorkeeper
  module Models
    module Avatarable
      extend ActiveSupport::Concern

      included do
        has_attached_file :avatar

        validates_attachment_content_type :avatar, content_type: %r{\Aimage\/.*\z}
      end
    end
  end
end

