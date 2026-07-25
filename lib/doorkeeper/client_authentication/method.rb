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

      # Whether this method authenticates clients with a shared symmetric
      # secret. Some contexts must refuse such methods — e.g. Client ID
      # Metadata Document clients, with whom no secret can have been
      # established (draft Section 4.1).
      #
      # Strategies may declare this themselves by defining
      # +uses_shared_secret?+; for strategies that don't, the registration
      # name is checked for "client_secret" as a conservative fallback, so an
      # undeclared method errs on the side of being treated as secret-based.
      def uses_shared_secret?
        if strategy.respond_to?(:uses_shared_secret?)
          strategy.uses_shared_secret?
        else
          name.to_s.include?("client_secret")
        end
      end
    end
  end
end
