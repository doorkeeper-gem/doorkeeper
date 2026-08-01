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

      # The IANA token endpoint authentication method name the wrapped
      # strategy implements, which is the strategy's own knowledge — unlike
      # +name+, the registration key a host application chooses freely and
      # which the two need not share. Callers matching a name a client wrote
      # down (a metadata document's token_endpoint_auth_method) must compare
      # against this one.
      #
      # A strategy that declares none answers +nil+, which no such name can
      # match: Doorkeeper::Server stamps this same value onto the credentials,
      # so a nameless strategy could never satisfy the check a document client
      # is held to anyway.
      def auth_method_name
        strategy.auth_method_name if strategy.respond_to?(:auth_method_name)
      end
    end
  end
end
