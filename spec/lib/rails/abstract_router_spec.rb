# frozen_string_literal: true

require "spec_helper"

RSpec.describe Doorkeeper::Rails::AbstractRouter do
  it "requires including routers to implement #generate_routes!" do
    router_class = Class.new { include Doorkeeper::Rails::AbstractRouter }
    router = router_class.new(double, double(map: nil))

    expect { router.generate_routes! }
      .to raise_error(NotImplementedError, /must be redefined/)
  end
end
