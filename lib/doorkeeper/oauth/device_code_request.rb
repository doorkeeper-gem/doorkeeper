module Doorkeeper
  module OAuth
    class DeviceCodeRequest
      attr_accessor :pre_auth

      def initialize(pre_auth)
        @pre_auth = pre_auth
      end

      def authorize
        if pre_auth.authorizable?
          auth = Authorization::DeviceCode.new(pre_auth)
          auth.issue_token
          @response = DeviceCodeResponse.new(auth.token)
        else
          @response = ErrorResponse.from_request(pre_auth)
        end
      end
    end
  end
end
