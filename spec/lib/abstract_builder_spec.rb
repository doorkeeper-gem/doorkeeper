# frozen_string_literal: true

require "spec_helper"

RSpec.describe Doorkeeper::Config::AbstractBuilder do
  it "wraps the given config without requiring a block" do
    config = Object.new
    builder = described_class.new(config)

    expect(builder.config).to be(config)
  end

  it "returns the config from #build, validating only when supported" do
    config = Object.new
    builder = described_class.new(config)

    expect(builder.build).to be(config)
  end
end
