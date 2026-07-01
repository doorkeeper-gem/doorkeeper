# frozen_string_literal: true

module Doorkeeper
  module ClientAuthentication
    # Adapter that lets a legacy callable +client_credentials+ extractor
    # (e.g. +->(request) { [client_id, client_secret] }+) keep working through
    # the client authentication registry during the deprecation window.
    #
    # The callable is expected to return a +[uid, secret]+ pair (or +nil+ when
    # it does not apply), matching the historical +Credentials.from_request+
    # contract. It is considered to match a request whenever it yields present
    # credentials, mirroring the previous "first extractor that returns a uid
    # wins" behaviour.
    class LegacyCallable
      def initialize(callable)
        @callable = callable
      end

      def matches_request?(request)
        credentials_for(request).present?
      end

      def authenticate(request)
        credentials_for(request)
      end

      private

      # Invoke the wrapped extractor at most once per request. +matches_request?+
      # and +authenticate+ both need the extracted credentials, and the legacy
      # +Credentials.from_request+ contract called each extractor exactly once,
      # so cache the result on the request itself to preserve that. The adapter
      # is stored in the config/registry and therefore shared across requests
      # and threads, so the cache must live on the per-request +env+ (keyed per
      # adapter instance) rather than on the adapter, which would otherwise race.
      def credentials_for(request)
        request.env[cache_key] ||=
          Doorkeeper::ClientAuthentication::Credentials.new(*@callable.call(request))
      end

      def cache_key
        @cache_key ||= "doorkeeper.client_authentication.legacy_callable.#{@callable.object_id}"
      end
    end
  end
end
