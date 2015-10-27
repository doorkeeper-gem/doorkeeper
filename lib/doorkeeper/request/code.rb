require 'doorkeeper/request/strategy'

module Doorkeeper
  module Request
    class Code < Strategy
      attr_accessor :pre_auth

      def initialize(server)
        super
        @pre_auth = server.context.send(:pre_auth)
      end

      def request
        @request ||= OAuth::CodeRequest.new(pre_auth, server.current_resource_owner)
      end
    end
  end
end
