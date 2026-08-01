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
      #
      # Answered as a String whatever the strategy declared it as — a Symbol
      # comes naturally to a strategy registered under one — so that every
      # comparison made against it (the metadata endpoint's, a document's,
      # Client.authenticate's) sees the one shape.
      def auth_method_name
        strategy.auth_method_name&.to_s if strategy.respond_to?(:auth_method_name)
      end

      # The JWS "alg" values the wrapped strategy accepts on the assertion it
      # authenticates a client with. RFC 8414 Section 2 has
      # token_endpoint_auth_signing_alg_values_supported published whenever an
      # assertion-based method — private_key_jwt, client_secret_jwt — is
      # advertised, and the strategy is the only thing that knows what it
      # verifies, so the metadata endpoint asks rather than keeping a list of
      # its own.
      #
      # A strategy that authenticates no assertion declares nothing and answers
      # nil, which is what leaves the entry off a server advertising no such
      # method. Answered as Strings whatever the strategy declared them as, for
      # the same reason +auth_method_name+ is.
      def auth_signing_alg_values
        return unless strategy.respond_to?(:auth_signing_alg_values)

        Array(strategy.auth_signing_alg_values).map(&:to_s).presence
      end
    end
  end
end
