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
      def doorkeeper_authorize!(*scopes, dpop: nil)
        endpoint_scopes = endpoint.route_setting(:scopes) ||
                          endpoint.options[:route_options][:scopes]

        scopes = if endpoint_scopes
                   Doorkeeper::OAuth::Scopes.from_array(endpoint_scopes)
                 elsif scopes.present?
                   Doorkeeper::OAuth::Scopes.from_array(scopes)
                 end

        endpoint_dpop = endpoint.route_setting(:dpop) ||
                        endpoint.options[:route_options][:dpop]

        super(*scopes, dpop: endpoint_dpop || dpop)
      end

      def doorkeeper_render_error_with(error)
        status_code = error_status_codes[error.status]
        error!({ error: error.description }, status_code, error.headers)
      end

      private

      def endpoint
        env["api.endpoint"]
      end

      def __doorkeeper_request__
        AuthorizationDecorator.new(request)
      end

      def error_status_codes
        {
          unauthorized: 401,
          forbidden: 403,
        }
      end
    end
  end
end
