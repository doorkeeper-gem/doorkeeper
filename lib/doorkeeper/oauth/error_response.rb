# frozen_string_literal: true

module Doorkeeper
  module OAuth
    class ErrorResponse < BaseResponse
      include OAuth::Helpers

      NON_REDIRECTABLE_STATES = %i[invalid_redirect_uri invalid_client unauthorized_client].freeze

      def self.from_request(request, attributes = {})
        new(
          attributes.merge(
            name: error_name_for(request.error),
            exception_class: exception_class_for(request.error),
            translate_options: request.error.try(:translate_options),
            state: request.try(:state),
            redirect_uri: request.try(:redirect_uri),
          ),
        )
      end

      def self.error_name_for(error)
        error.respond_to?(:name_for_response) ? error.name_for_response : error
      end

      def self.exception_class_for(error)
        return error if error.respond_to?(:name_for_response)

        "Doorkeeper::Errors::#{error.to_s.classify}".safe_constantize
      end

      private_class_method :error_name_for, :exception_class_for

      delegate :name, :description, :state, to: :@error

      def initialize(attributes = {})
        @error = OAuth::Error.new(*attributes.values_at(:name, :state, :translate_options))
        @exception_class = attributes[:exception_class]
        @redirect_uri = attributes[:redirect_uri]
        @response_on_fragment = attributes[:response_on_fragment]
      end

      def body
        {
          error: name,
          error_description: description,
          state: state,
        }.reject { |_, v| v.blank? }
      end

      def status
        if name == :invalid_client || name == :unauthorized_client
          :unauthorized
        else
          :bad_request
        end
      end

      def redirectable?
        !NON_REDIRECTABLE_STATES.include?(name) && !URIChecker.oob_uri?(@redirect_uri)
      end

      def redirect_uri
        if @response_on_fragment
          Authorization::URIBuilder.uri_with_fragment(@redirect_uri, body)
        else
          Authorization::URIBuilder.uri_with_query(@redirect_uri, body)
        end
      end

      def headers
        {
          "Cache-Control" => "no-store, no-cache",
          "Content-Type" => "application/json; charset=utf-8",
          "WWW-Authenticate" => authenticate_info,
        }
      end

      def raise_exception!
        raise exception_class.new(self), description
      end

      protected

      def realm
        Doorkeeper.config.realm
      end

      def exception_class
        return @exception_class if @exception_class
        raise NotImplementedError, "error response must define #exception_class"
      end

      private

      def authenticate_info
        %(Bearer realm="#{realm}", error="#{name}", error_description="#{description}")
      end
    end
  end
end
