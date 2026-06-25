# frozen_string_literal: true

module Doorkeeper
  module ClientAuthentication
    # Wraps a registered client authentication method, pairing its
    # registration +name+ with the +method+ object that knows how to match
    # and authenticate a request.
    class Method
      attr_reader :name, :method

      delegate :matches_request?, to: :method

      def initialize(name, method)
        @name = name
        @method = method
      end
    end
  end
end
