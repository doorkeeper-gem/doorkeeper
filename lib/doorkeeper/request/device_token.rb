require 'doorkeeper/request/strategy'

module Doorkeeper
  module Request
    class DeviceToken < Strategy
      delegate :device_grant, :client, to: :server

      def request
        @request ||= OAuth::DeviceTokenRequest.new(Doorkeeper.configuration,
                                                   device_grant,
                                                   client)
      end
    end
  end
end
