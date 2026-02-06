# frozen_string_literal: true

require "active_support"

module Sprockets
  module Rails
    def self.deprecator
      @deprecator ||= ActiveSupport::Deprecation.new("4.0", "Sprockets::Rails")
    end
  end
end
