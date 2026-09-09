# frozen_string_literal: true

require "doorkeeper/grape/authorization_decorator"

module Doorkeeper
  module Grape
    # Doorkeeper helpers for Grape applications.
    # Provides helpers for endpoints authorization based on defined set of scopes.
    module Helpers
      # These helpers are for grape >= 0.10
      extend ::Grape::API::Helpers
      include Doorkeeper::Rails::Helpers

      # endpoint specific scopes > parameter scopes > default scopes
      def doorkeeper_authorize!(*scopes)
        endpoint_scopes = endpoint.route_setting(:scopes) ||
                          endpoint.options[:route_options][:scopes]

        scopes = if endpoint_scopes
                   Doorkeeper::OAuth::Scopes.from_array(endpoint_scopes)
                 elsif scopes.present?
                   Doorkeeper::OAuth::Scopes.from_array(scopes)
                 end

        super(*scopes)
      end

      def doorkeeper_render_error_with(error)
        status_code = error_status_codes[error.status]
        error!({ error: error.description }, status_code, error.headers)
      end

      private

      def endpoint
        env["api.endpoint"]
      end

      # Memoized with the same defined? guard as Rails::Helpers#doorkeeper_token:
      # both a request without a usable token and a refused multi-method request
      # leave @doorkeeper_token nil, which ||= would re-evaluate on every call —
      # re-running authentication just to reach the same verdict again.
      def doorkeeper_token
        return @doorkeeper_token if defined?(@doorkeeper_token)

        @doorkeeper_token = OAuth::Token.authenticate(
          decorated_request,
          *Doorkeeper.config.access_token_methods,
        )
      rescue Errors::MultipleAccessTokenMethods => e
        @_doorkeeper_multiple_token_methods_error = e
        @doorkeeper_token = nil
      end

      def decorated_request
        AuthorizationDecorator.new(request)
      end

      def error_status_codes
        {
          bad_request: 400,
          unauthorized: 401,
          forbidden: 403,
        }
      end
    end
  end
end
