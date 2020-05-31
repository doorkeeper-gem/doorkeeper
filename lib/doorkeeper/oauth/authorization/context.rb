# frozen_string_literal: true

module Doorkeeper
  module OAuth
    module Authorization
      class Context
        attr_reader :client, :grant_type, :resource_owner, :scopes

        def initialize(**attributes)
          attributes.each do |name, value|
            instance_variable_set(:"@#{name}", value) if respond_to?(name)
          end
        end
      end
    end
  end
end
