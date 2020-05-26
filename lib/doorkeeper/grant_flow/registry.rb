# frozen_string_literal: true

module Doorkeeper
  module GrantFlow
    module Registry
      mattr_accessor :flows
      self.flows = {}

      # Only for retro-compatibility, will be removed soon
      FALLBACK_FLOW = FallbackFlow.new

      def register(name_or_flow, **options)
        unless name_or_flow.is_a?(Doorkeeper::GrantFlow::Flow)
          name_or_flow = Flow.new(name_or_flow, **options)
        end

        flows[name_or_flow.name.to_sym] = name_or_flow
      end

      def get(name)
        flows.fetch(name.to_sym, FALLBACK_FLOW)
      end
    end
  end
end
