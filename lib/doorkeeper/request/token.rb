require 'doorkeeper/request/strategy'

module Doorkeeper
  module Request
    class Token < Strategy
      attr_accessor :pre_auth

      def initialize(server)
        super
        @pre_auth = server.context.send(:pre_auth)
      end

      def request
        @request ||= OAuth::TokenRequest.new(pre_auth, server.current_resource_owner)
      end
    end
  end
end
