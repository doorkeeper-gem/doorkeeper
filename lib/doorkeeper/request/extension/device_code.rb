# frozen_string_literal: true

module Doorkeeper
  module Request
    module Extension
      # This strategy defines how to map parameters for DeviceCode Token Request
      # to implement section 3.4 from:
      # https://tools.ietf.org/html/draft-ietf-oauth-device-flow-15#section-3.4
      class DeviceCode < Strategy
        delegate :parameters, to: :server

        def access_grant
          AccessGrant.find_by!(token: parameters[:device_code])
        end

        def client
          server.client
        end

        def request
          @request ||= OAuth::DeviceCodeRequest.new(Doorkeeper.configuration, access_grant, client)
        end
      end
    end
  end
end
