module Doorkeeper
  module Rails
    module Helpers
      extend ActiveSupport::Concern

      def doorkeeper_authorize!(*scopes)
        @_doorkeeper_scopes = scopes.presence || Doorkeeper.configuration.default_scopes

        if !valid_doorkeeper_token?
          doorkeeper_render_error
        end
      end

      def doorkeeper_unauthorized_render_options(error)
        nil
      end

      def doorkeeper_forbidden_render_options(error)
        nil
      end

      def valid_doorkeeper_token?
        doorkeeper_token && doorkeeper_token.acceptable?(@_doorkeeper_scopes)
      end

      private

      def doorkeeper_render_error
        error = doorkeeper_error
        headers.merge! error.headers.reject { |k| "Content-Type" == k }
        doorkeeper_render_error_with(error)
      end

      def doorkeeper_render_error_with(error)
        options = doorkeeper_render_options(error) || {}
        if options.blank?
          head error.status
        else
          options[:status] = error.status
          options[:layout] = false if options[:layout].nil?
          render options
        end
      end

      def doorkeeper_error
        if doorkeeper_invalid_token_response?
          OAuth::InvalidTokenResponse.from_access_token(doorkeeper_token)
        else
          OAuth::ForbiddenTokenResponse.from_scopes(@_doorkeeper_scopes)
        end
      end

      def doorkeeper_render_options(error)
        if doorkeeper_invalid_token_response?
          doorkeeper_unauthorized_render_options(error)
        else
          doorkeeper_forbidden_render_options(error)
        end
      end

      def doorkeeper_invalid_token_response?
        !doorkeeper_token || !doorkeeper_token.accessible?
      end

      def doorkeeper_token
        @_doorkeeper_token ||= OAuth::Token.authenticate(
          request,
          *Doorkeeper.configuration.access_token_methods
        )
      end
    end
  end
end
