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
      # secret. Callers that must refuse such methods — because no secret
      # can have been established with the client — can ask the registry
      # instead of keeping a hard-coded list of method names.
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

      # The JWS "alg" values the strategy accepts on the assertion it
      # authenticates a client with, as Strings. RFC 8414 §2 has them
      # published whenever an assertion-based method (private_key_jwt,
      # client_secret_jwt) is advertised, and the strategy is the only thing
      # that knows what it verifies.
      #
      # Strategies declare them by defining +auth_signing_alg_values+; one
      # that authenticates no assertion declares nothing and answers nil.
      def auth_signing_alg_values
        return unless strategy.respond_to?(:auth_signing_alg_values)

        Array(strategy.auth_signing_alg_values).map(&:to_s).presence
      end
    end
  end
end
