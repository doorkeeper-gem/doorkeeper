# frozen_string_literal: true

require "spec_helper"

RSpec.describe Doorkeeper::ClientAuthentication::Credentials do
  it "is blank when the uid is blank" do
    expect(described_class.new(nil, nil)).to be_blank
    expect(described_class.new(nil, "something")).to be_blank
    expect(described_class.new("something", nil)).to be_present
    expect(described_class.new("something", "something")).to be_present
  end

  it "exposes uid and secret" do
    credentials = described_class.new("some-uid", "some-secret")

    expect(credentials.uid).to eq("some-uid")
    expect(credentials.secret).to eq("some-secret")
  end
end
