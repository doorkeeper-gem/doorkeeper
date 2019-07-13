# frozen_string_literal: true

module Doorkeeper
  module Request
    class ErrorResponseType < Strategy
      def pre_auth
        server.context.send(:pre_auth)
      end

      def request
        @request ||= OAuth::ErrorResponseTypeRequest.new(pre_auth)
      end
    end
  end
end
