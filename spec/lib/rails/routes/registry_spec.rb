# frozen_string_literal: true

require "spec_helper"

RSpec.describe Doorkeeper::Rails::Routes::Registry do
  subject(:registry) { Object.new.extend(described_class) }

  describe "#register_routes" do
    it "registers a router class that includes AbstractRouter" do
      router = Class.new { include Doorkeeper::Rails::AbstractRouter }

      registry.register_routes(router)

      expect(registry.registered_routes).to include(router)
    end

    it "rejects a class that does not include AbstractRouter" do
      expect { registry.register_routes(Class.new) }.to raise_error(
        described_class::InvalidRouterClass,
        /must include Doorkeeper::Rails::AbstractRouter/,
      )
    end

    it "rejects objects that are not a module at all" do
      expect { registry.register_routes("not a router") }
        .to raise_error(described_class::InvalidRouterClass)
    end
  end
end
