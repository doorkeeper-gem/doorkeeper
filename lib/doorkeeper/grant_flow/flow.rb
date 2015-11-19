module Doorkeeper
  module GrantFlow
    class Flow
      attr_accessor :name,
                    :grant_type_matches, :grant_type_strategy,
                    :response_type_matches, :response_type_strategy

      def initialize(name, options = {})
        self.name = name
        self.grant_type_matches = options[:grant_type_matches]
        self.grant_type_strategy = options[:grant_type_strategy]
        self.response_type_matches = options[:response_type_matches]
        self.response_type_strategy = options[:response_type_strategy]
      end

      def handles_grant_type?
        grant_type_matches.present?
      end

      def handles_response_type?
        response_type_matches.present?
      end

      def matches_grant_type?(value)
        grant_type_matches === value
      end

      def matches_response_type?(value)
        response_type_matches === value
      end
    end
  end
end
