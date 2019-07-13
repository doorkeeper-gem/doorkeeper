# frozen_string_literal: true

module Doorkeeper
  module OAuth
    class ErrorResponseTypeRequest
      attr_accessor :pre_auth

      def initialize(pre_auth)
        @pre_auth = pre_auth
      end

      def authorize
        @response = if pre_auth.error == :invalid_request
                      InvalidRequestResponse.from_request pre_auth
                    else
                      ErrorResponse.from_request pre_auth
                    end
      end
    end
  end
end
