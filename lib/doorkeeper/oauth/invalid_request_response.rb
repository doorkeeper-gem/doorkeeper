# frozen_string_literal: true

module Doorkeeper
  module OAuth
    class InvalidRequestResponse < ErrorResponse
      attr_reader :reason

      def self.from_request(request, attributes = {})
        new(
          attributes.merge(
            state: request.try(:state),
            redirect_uri: request.try(:redirect_uri),
            missing_param: request.try(:missing_param),
            reason: request.try(:invalid_request_reason)
          )
        )
      end

      def initialize(attributes = {})
        super(attributes.merge(name: :invalid_request))
        @missing_param = attributes[:missing_param]
        @reason = attributes[:reason]
      end

      def status
        :bad_request
      end

      def description
        @reason = :missing_param unless @missing_param.nil?

        I18n.translate(
          @reason,
          scope: %i[doorkeeper errors messages invalid_request],
          default: :default_message,
          value: @missing_param
        )
      end
    end
  end
end
