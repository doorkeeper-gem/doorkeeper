# frozen_string_literal: true

module Doorkeeper
  module GrantFlow
    module Registry
      mattr_accessor :flows
      self.flows = {}

      def register(name_or_flow, **options)
        unless name_or_flow.is_a?(Doorkeeper::GrantFlow::Flow)
          name_or_flow = Flow.new(name_or_flow, **options)
        end

        flows[name_or_flow.name.to_sym] = name_or_flow
      end

      # [NOTE]: make it to use #fetch after removing fallbacks
      def get(name)
        flows[name.to_sym]
      end
    end
  end
end
