# frozen_string_literal: true

module Doorkeeper
  module OAuth
    class Client
      Credentials = Struct.new(:uid, :secret) do
        class << self
          # Extracts the client credentials from the request using the
          # configured extraction methods. The first method that yields
          # credentials wins, as it always has.
          #
          # Raises Errors::MultipleClientAuthMethods when the request
          # authenticates the client with more than one method, which RFC 6749
          # §2.3 forbids ("The client MUST NOT use more than one authentication
          # method in each request").
          def from_request(request, *credentials_methods)
            # Callable extractors are opaque: they may legitimately overlap the
            # built-in methods they are configured with, and evaluating all of
            # them would also break the existing contract that the extractors
            # after the matching one are not called. Such configurations keep
            # the historical behaviour untouched.
            return first_from_request(request, credentials_methods) unless credentials_methods.all?(Symbol)

            credentials = credentials_methods.filter_map { |method| extract(request, method) }

            # Only credentials carrying a secret authenticate the client. A bare
            # uid is a public client identifying itself (RFC 6749 §2.3 "none"),
            # not an authentication method of its own, so it doesn't count
            # towards the single-method rule — RFC 7521 §4.2, for example,
            # explicitly allows a client_id next to another authentication
            # method.
            raise Errors::MultipleClientAuthMethods if credentials.count { |c| c.secret.present? } > 1

            credentials.first
          end

          def from_params(request)
            request.parameters.values_at(:client_id, :client_secret)
          end

          def from_basic(request)
            authorization = request.authorization
            if authorization.present? && authorization =~ /^Basic (.*)/im
              Base64.decode64(Regexp.last_match(1)).split(/:/, 2)
            end
          end

          private

          def first_from_request(request, credentials_methods)
            credentials_methods.inject(nil) do |_, method|
              credentials = extract(request, method)
              break credentials if credentials
            end
          end

          # Returns the credentials the given method extracts from the request,
          # or nil when it extracts none.
          def extract(request, method)
            method = self.method(method) if method.is_a?(Symbol)
            Credentials.new(*method.call(request)).presence
          end
        end

        # Public clients may have their secret blank, but "credentials" are
        # still present
        delegate :blank?, to: :uid
      end
    end
  end
end
