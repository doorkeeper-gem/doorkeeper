# frozen_string_literal: true

module Doorkeeper
  module ClientAuthentication
    # Wraps a registered client authentication method, pairing its
    # registration +name+ with the +strategy+ object that knows how to match
    # and authenticate a request.
    #
    # NOTE: the wrapped object is exposed as +strategy+ rather than +method+ on
    # purpose — an +attr_reader :method+ would shadow Ruby's core
    # +Object#method+ reflection API and break +wrapper.method(:authenticate)+.
    class Method
      attr_reader :name, :strategy

      delegate :matches_request?, :authenticate, to: :strategy

      def initialize(name, strategy)
        @name = name
        @strategy = strategy
      end
    end
  end
end
