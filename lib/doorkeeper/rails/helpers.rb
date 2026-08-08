# frozen_string_literal: true

module Doorkeeper
  module Rails
    module Helpers
      def doorkeeper_authorize!(*scopes)
        @_doorkeeper_scopes = scopes.presence || Doorkeeper.config.default_scopes

        doorkeeper_render_error unless valid_doorkeeper_token?
      end

      def doorkeeper_unauthorized_render_options(**); end

      def doorkeeper_forbidden_render_options(**); end

      def doorkeeper_bad_request_render_options(**); end

      def valid_doorkeeper_token?
        doorkeeper_token&.acceptable?(@_doorkeeper_scopes)
      end

      private

      def doorkeeper_render_error
        error = doorkeeper_error
        error.raise_exception! if Doorkeeper.config.raise_on_errors?

        headers.merge!(error.headers.reject { |k| k == "Content-Type" })
        doorkeeper_render_error_with(error)
      end

      def doorkeeper_render_error_with(error)
        options = doorkeeper_render_options(error) || {}
        status = doorkeeper_status_for_error(
          error, options.delete(:respond_not_found_when_forbidden),
        )
        if options.blank?
          head status
        else
          options[:status] = status
          options[:layout] = false if options[:layout].nil?
          render options
        end
      end

      def doorkeeper_error
        if @_doorkeeper_multiple_token_methods_error
          OAuth::InvalidRequestResponse.new(
            reason: @_doorkeeper_multiple_token_methods_error.reason,
          )
        elsif doorkeeper_invalid_token_response?
          OAuth::InvalidTokenResponse.from_access_token(doorkeeper_token)
        else
          OAuth::ForbiddenTokenResponse.from_scopes(@_doorkeeper_scopes)
        end
      end

      # Keyed on the response doorkeeper_error chose rather than on the state
      # that chose it, so a response this method does not know about cannot be
      # rendered through a hook meant for a different one: a request refused
      # for transmitting the token by more than one method leaves
      # doorkeeper_token nil, and answering it through the hook a host wrote
      # for its 401s would give an "unauthorized" body a 400 status.
      def doorkeeper_render_options(error)
        case error.status
        when :bad_request
          doorkeeper_bad_request_render_options(error: error)
        when :unauthorized
          doorkeeper_unauthorized_render_options(error: error)
        else
          doorkeeper_forbidden_render_options(error: error)
        end
      end

      def doorkeeper_status_for_error(error, respond_not_found_when_forbidden)
        if respond_not_found_when_forbidden && error.status == :forbidden
          :not_found
        else
          error.status
        end
      end

      def doorkeeper_invalid_token_response?
        !doorkeeper_token || !doorkeeper_token.accessible?
      end

      # Answers nil (not a raise) when the request transmits an access token
      # by more than one method, so host code that consults doorkeeper_token
      # directly keeps its token-or-nil contract; doorkeeper_authorize! then
      # renders the invalid_request (400) response RFC 6750 §3.1 prescribes
      # instead of invalid_token, via doorkeeper_error above.
      def doorkeeper_token
        return @doorkeeper_token if defined?(@doorkeeper_token)

        @doorkeeper_token = OAuth::Token.authenticate(
          request,
          *Doorkeeper.config.access_token_methods,
        )
      rescue Errors::MultipleAccessTokenMethods => e
        @_doorkeeper_multiple_token_methods_error = e
        @doorkeeper_token = nil
      end
    end
  end
end
