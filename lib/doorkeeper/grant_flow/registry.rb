# frozen_string_literal: true

module Doorkeeper
  module GrantFlow
    module Registry
      mattr_accessor :flows
      self.flows = {}

      mattr_accessor :aliases
      self.aliases = {}

      # Allows to register custom OAuth grant flow so that Doorkeeper
      # could recognize and process it.
      #
      def register(name_or_flow, **options)
        unless name_or_flow.is_a?(Doorkeeper::GrantFlow::Flow)
          name_or_flow = Flow.new(name_or_flow, **options)
        end

        flow_key = name_or_flow.name.to_sym

        if flows.key?(flow_key)
          ::Kernel.warn <<~WARNING
            [DOORKEEPER] '#{flow_key}' grant flow already registered and will be overridden
            in #{caller(1..1).first}
          WARNING
        end

        flows[flow_key] = name_or_flow
      end

      # Allows to register aliases that could be used in `grant_flows`
      # configuration option. It is possible to have aliases like 1:1 or
      # 1:N, i.e. "implicit_oidc" => ['token', 'id_token', 'id_token token'].
      #
      def register_alias(alias_name, **options)
        aliases[alias_name.to_sym] = Array.wrap(options.fetch(:as))
      end

      def expand_alias(alias_name)
        aliases.fetch(alias_name.to_sym, [])
      end

      # [NOTE]: make it to use #fetch after removing fallbacks
      def get(name)
        flows[name.to_sym]
      end
    end
  end
end
