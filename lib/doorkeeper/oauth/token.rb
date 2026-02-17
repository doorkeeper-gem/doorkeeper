# frozen_string_literal: true

module Doorkeeper
  module OAuth
    class Token
      # Built-in extractors that read a request parameter, and the parameter
      # each of them reads. RFC 6750 treats the form-encoded body (§2.2) and
      # the URI query string (§2.3) as two distinct transmission methods, but
      # Rack and ActionDispatch both collapse them into a single parameter
      # hash — ActionDispatch lets the query win, Rack lets the body win — so
      # a request carrying the parameter in both would present a single value
      # to the extractor and never be refused. The multi-method check reads
      # the two sources separately for these extractors; selection keeps
      # using the extractor, so which one wins is unchanged.
      PARAMETER_EXTRACTORS = {
        from_access_token_param: "access_token",
        from_bearer_param: "bearer_token",
      }.freeze

      Resolution = Struct.new(:access_token_method, :plaintext_token, :access_token)

      class << self
        # RFC 6750 §2: "Clients MUST NOT use more than one method to transmit
        # the token in each request", and §3.1 lists using more than one method
        # among the conditions an invalid_request answers. Returning the first
        # method that yields a value would discard every other token presented
        # in the same request with no error, warning or log entry, leaving
        # which token authorizes the request to be decided by the configured
        # order of +access_token_methods+ rather than by what the caller sent —
        # so a layer in front of Doorkeeper that reads a different one of them
        # can reach a different verdict about the very same request.
        #
        # What §2 forbids is using more than one method, so the check counts
        # transmission methods rather than comparing the tokens they carry:
        # the same value presented twice is still two methods, and is refused
        # by raising Errors::MultipleAccessTokenMethods so callers can answer
        # with the invalid_request (400) response §3.1 prescribes — the same
        # shape Request.client_authentication_method gives the client
        # authentication side with Errors::MultipleClientAuthMethods.
        #
        # Only the built-in extractors — symbols naming methods on this class,
        # all of them side-effect-free reads of the request — take part in
        # that check. A custom callable extractor is a configuration adapter
        # rather than a transmission method: it keeps the historical
        # first-wins selection and is never invoked more than once, the same
        # exemption client authentication gives its legacy callable
        # extractors (Request#validate_client_authentication!).
        def from_request(request, *methods)
          refuse_multiple_transmission_methods!(request, methods)

          methods.inject(nil) do |_, method|
            method = self.method(method) if method.is_a?(Symbol)
            credentials = method.call(request)
            break credentials if credentials.present?
          end
        end

        # Resolves one method at a time, so the multi-method check has to run
        # here across every configured method before any single one is read:
        # inside from_request it would only ever see the one method it was
        # handed and could never count two.
        def resolve(request, *methods)
          refuse_multiple_transmission_methods!(request, methods)

          method, token = methods.lazy.map { |m| [m, from_request(request, m)] }.detect(&:last)
          access_token = Doorkeeper.config.access_token_model.by_token(token) if token

          if access_token && Doorkeeper.config.refresh_token_enabled? && !access_token.uses_dpop?
            access_token.revoke_previous_refresh_token!
          end

          Resolution.new(method, token, access_token) if access_token
        end

        def authenticate(request, *methods)
          resolve(request, *methods)&.access_token
        end

        def from_access_token_param(request)
          request.parameters[:access_token]
        end

        def from_bearer_param(request)
          request.parameters[:bearer_token]
        end

        def from_bearer_authorization(request)
          pattern = /^Bearer /i
          header = request.authorization
          token_from_header(header, pattern) if match?(header, pattern)
        end

        def from_dpop_authorization(request)
          pattern = /^DPoP /i
          header = request.authorization
          token_from_header(header, pattern) if match?(header, pattern)
        end

        def from_basic_authorization(request)
          pattern = /^Basic /i
          header = request.authorization
          token_from_basic_header(header, pattern) if match?(header, pattern)
        end

        private

        def refuse_multiple_transmission_methods!(request, methods)
          used = methods.sum do |method|
            method.is_a?(Symbol) ? transmission_methods_used(request, method) : 0
          end

          raise Errors::MultipleAccessTokenMethods if used > 1
        end

        # How many transmission methods the given built-in extractor finds a
        # token in. Usually one, or none — but for the parameter extractors
        # above it is the body and the query counted separately, since the
        # parameter hash collapsed them into the single value the extractor
        # reads. That value is counted on its own only when neither raw source
        # explains it, so a token reaching the extractor by some other route —
        # an :access_token path segment, or a host that overrode the extractor
        # — is still counted exactly once rather than twice.
        def transmission_methods_used(request, method)
          value = self.method(method).call(request).presence

          parameter = PARAMETER_EXTRACTORS[method]
          return value ? 1 : 0 unless parameter

          sources = parameter_sources(request, parameter)
          sources.size + (value && !sources.include?(value) ? 1 : 0)
        end

        # The form-encoded body (§2.2) and the URI query (§2.3) as Rack
        # exposes them, for a request object that keeps the two apart.
        def parameter_sources(request, parameter)
          return [] unless request.respond_to?(:GET) && request.respond_to?(:POST)

          query = request.GET
          body = request.POST
          return [] unless query.is_a?(Hash) && body.is_a?(Hash)

          [query[parameter], body[parameter]].filter_map(&:presence)
        end

        def token_from_basic_header(header, pattern)
          encoded_header = token_from_header(header, pattern)
          decode_basic_credentials_token(encoded_header)
        end

        def decode_basic_credentials_token(encoded_header)
          Base64.decode64(encoded_header).split(/:/, 2).first
        end

        def token_from_header(header, pattern)
          header.gsub(pattern, "")
        end

        def match?(header, pattern)
          header&.match(pattern)
        end
      end
    end
  end
end
