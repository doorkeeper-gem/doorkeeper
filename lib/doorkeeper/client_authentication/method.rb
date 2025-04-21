# frozen_string_literal: true

module Doorkeeper
  module ClientAuthentication
    class Method
      attr_reader :name, :method
      delegate :matches_request?, to: :method
        
      def initialize(name, **options)
        @name = name
        @method = options[:method]
      end
    end
  end
end
