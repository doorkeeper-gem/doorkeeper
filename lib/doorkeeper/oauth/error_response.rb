module Doorkeeper
  module OAuth
    class ErrorResponse
      include ActiveModel::Serializers::JSON

      self.include_root_in_json = false

      def self.from_request(request)
        state = request.state if request.respond_to?(:state)
        new(:name => request.error, :state => state)
      end

      delegate :name, :description, :state, :to => :@error
      alias    :error :name
      alias    :error_description :description

      def initialize(attributes = {})
        @error = Doorkeeper::OAuth::Error.new(*attributes.values_at(:name, :state))
      end

      def attributes
        { :error => name, :error_description => description, :state => state }.reject { |k, v| v.blank? }
      end

      def status
        :unauthorized
      end
    end
  end
end
