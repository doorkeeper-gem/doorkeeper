# frozen_string_literal: true

require "spec_helper"

RSpec.describe Doorkeeper::OAuth::Helpers::ResourceIndicatorsChecker do
  describe ".valid?" do
    before do
      allow(Doorkeeper.config).to receive(:using_resource_indicators?).and_return(true)
    end

    let(:subject) do
      described_class.valid?(
        double(resource_indicators: Doorkeeper::OAuth::ResourceIndicators.from_array(preapproved_indicators)),
        Doorkeeper::OAuth::ResourceIndicators.from_array(requested_indicators),
      )
    end

    context "when preapproved is a superset" do
      let(:preapproved_indicators) do
        ["http://example.com/1", "http://example.com/2"]
      end

      let(:requested_indicators) do
        ["http://example.com/1"]
      end

      it { is_expected.to be true }
    end

    context "when preapproved is a subset" do
      let(:preapproved_indicators) do
        ["http://example.com/1"]
      end

      let(:requested_indicators) do
        ["http://example.com/1", "http://example.com/2"]
      end

      it { is_expected.to be false }
    end

    context "when preapproved is a empty" do
      let(:preapproved_indicators) do
        []
      end

      let(:requested_indicators) do
        ["http://example.com/1", "http://example.com/2"]
      end

      it { is_expected.to be false }
    end

    context "when both are empty " do
      let(:preapproved_indicators) do
        []
      end

      let(:requested_indicators) do
        []
      end

      it { is_expected.to be true }
    end

    context "when both are set and equal" do
      let(:preapproved_indicators) do
        ["http://example.com/1"]
      end

      let(:requested_indicators) do
        ["http://example.com/1"]
      end

      it { is_expected.to be true }
    end
  end
end
