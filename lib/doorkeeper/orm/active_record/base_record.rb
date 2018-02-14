# frozen_string_literal: true

module Doorkeeper
  class BaseRecord < ActiveRecord::Base
    self.abstract_class = true

    def self.ordered_by(attribute, direction = :asc)
      order(attribute => direction)
    end
  end
end
