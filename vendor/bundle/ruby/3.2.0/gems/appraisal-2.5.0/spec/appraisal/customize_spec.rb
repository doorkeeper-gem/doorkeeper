require "spec_helper"
require "appraisal/customize"

describe Appraisal::Customize do
  it "has defaults" do
    expect(described_class.heading).to eq nil
    expect(described_class.single_quotes).to eq false
    expect { described_class.new }.to_not(change do
      [described_class.heading, described_class.single_quotes]
    end)
  end

  it "can override defaults" do
    described_class.new(single_quotes: true, heading: "foo")
    expect(described_class.heading).to eq "foo"
    expect(described_class.single_quotes).to eq true
  end
end
