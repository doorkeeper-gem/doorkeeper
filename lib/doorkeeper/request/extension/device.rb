# frozen_string_literal: true

module Doorkeeper
  module Request
    module Extension
      # This strategy defines how to map parameters for DeviceRequest to implement section 3.1 from:
      # https://tools.ietf.org/html/draft-ietf-oauth-device-flow-15#section-3.1
      class Device < Strategy
        delegate :current_resource_owner, to: :server

        def client
          server.context.send(:client)
        end

        def host_name
          "#{server.context.request.scheme}://#{server.context.request.host}#{port}"
        end

        def port
          ":#{server.context.request.port}" unless [80, 443].include?(server.context.request.port)
        end

        def request
          @request ||= OAuth::DeviceRequest.new(Doorkeeper.configuration, client, host_name)
        end
      end
    end
  end
end
