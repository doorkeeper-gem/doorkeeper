require 'doorkeeper/request/strategy'

module Doorkeeper
  module Request
    class DeviceCode < Strategy
      def pre_auth
        server.context.send(:pre_auth)
      end

      def request
        @request ||= OAuth::DeviceCodeRequest.new(pre_auth)
      end
    end
  end
end
