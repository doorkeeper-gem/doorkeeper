module Doorkeeper
  module OAuth
    class ErrorResponse
      def self.from_request(request)
        state = request.state if request.respond_to?(:state)
        new(:name => request.error, :state => state)
      end

      delegate :name, :description, :state, :to => :@error

      def initialize(attributes = {})
        @error = Doorkeeper::OAuth::Error.new(*attributes.values_at(:name, :state))
      end

      def body
        { :error => name, :error_description => description, :state => state }.reject { |k, v| v.blank? }
      end

      def status
        :unauthorized
      end

      def headers
        { 'Cache-Control' => 'no-store', 'Pragma' => 'no-cache' }
      end
    end
  end
end
