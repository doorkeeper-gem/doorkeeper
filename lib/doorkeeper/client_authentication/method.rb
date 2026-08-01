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
      # Only a strategy that declares +uses_shared_secret?+ and answers
      # exactly +false+ is treated as secret-free. A strategy that declares
      # nothing, or answers anything else, is treated as secret-based: the
      # callers asking are deciding whether to admit a client that was never
      # registered, so an undeclared method has to fail closed rather than be
      # guessed at from its name.
      def uses_shared_secret?
        return true unless strategy.respond_to?(:uses_shared_secret?)

        strategy.uses_shared_secret? != false
      end
    end
  end
end
