# frozen_string_literal: true

require "spec_helper"

RSpec.describe Doorkeeper::GrantFlow::FallbackFlow do
  subject(:flow) { described_class.new("custom_type", response_type_matches: "custom_type") }

  it "reports that it handles neither grant nor response types" do
    expect(flow.handles_grant_type?).to be(false)
    expect(flow.handles_response_type?).to be(false)
  end

  it "still matches the configured response type for lookups" do
    expect(flow.matches_response_type?("custom_type")).to be(true)
  end
end
