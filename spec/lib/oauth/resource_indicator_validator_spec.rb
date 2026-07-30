# frozen_string_literal: true

require "spec_helper"

RSpec.describe Doorkeeper::OAuth::ResourceIndicatorValidator do
  describe ".validate!" do
    it "returns empty array when resource_indicators is nil" do
      expect(described_class.validate!(nil)).to eq([])
    end

    it "returns empty array when resource_indicators is blank" do
      expect(described_class.validate!("")).to eq([])
      expect(described_class.validate!([])).to eq([])
    end

    it "returns validated URIs for valid absolute URIs" do
      result = described_class.validate!(["https://api.example.com/"])
      expect(result).to eq(["https://api.example.com/"])
    end

    it "accepts multiple resource URIs" do
      uris = ["https://api.example.com/", "https://calendar.example.com/"]
      result = described_class.validate!(uris)
      expect(result).to eq(uris)
    end

    it "accepts a single string (wrapped into array)" do
      result = described_class.validate!("https://api.example.com/")
      expect(result).to eq(["https://api.example.com/"])
    end

    it "raises InvalidTarget for relative URIs" do
      expect do
        described_class.validate!(["/relative/path"])
      end.to raise_error(Doorkeeper::Errors::InvalidTarget)
    end

    it "raises InvalidTarget for URIs with fragments" do
      expect do
        described_class.validate!(["https://api.example.com/#fragment"])
      end.to raise_error(Doorkeeper::Errors::InvalidTarget)
    end

    it "raises InvalidTarget for invalid URIs" do
      expect do
        described_class.validate!(["not a uri at all %%%"])
      end.to raise_error(Doorkeeper::Errors::InvalidTarget)
    end

    it "raises InvalidTarget for non-String values (e.g. Hash from malformed params)" do
      expect do
        described_class.validate!([{ "foo" => "bar" }])
      end.to raise_error(Doorkeeper::Errors::InvalidTarget)
    end

    it "raises InvalidTarget for Integer values" do
      expect do
        described_class.validate!([123])
      end.to raise_error(Doorkeeper::Errors::InvalidTarget)
    end

    it "allows URIs with query components (per RFC 8707 §2)" do
      result = described_class.validate!(["https://api.example.com/app?tenant=foo"])
      expect(result).to eq(["https://api.example.com/app?tenant=foo"])
    end

    context "with a config_validator" do
      it "calls the validator with indicators and client" do
        validator = ->(indicators, _client) { indicators.all? { |r| r.start_with?("https://allowed.com/") } }
        client = double(:client)

        result = described_class.validate!(
          ["https://allowed.com/api"],
          config_validator: validator,
          client: client,
        )
        expect(result).to eq(["https://allowed.com/api"])
      end

      it "raises InvalidTarget when validator returns false" do
        validator = ->(_indicators, _client) { false }

        expect do
          described_class.validate!(["https://api.example.com/"], config_validator: validator)
        end.to raise_error(Doorkeeper::Errors::InvalidTarget)
      end
    end

    context "with grant_resource_indicators (subset enforcement)" do
      let(:grant_resources) { ["https://api.example.com/", "https://calendar.example.com/"] }

      it "allows a subset of the grant resources" do
        result = described_class.validate!(
          ["https://api.example.com/"],
          grant_resource_indicators: grant_resources,
        )
        expect(result).to eq(["https://api.example.com/"])
      end

      it "allows exact match of the grant resources" do
        result = described_class.validate!(
          grant_resources,
          grant_resource_indicators: grant_resources,
        )
        expect(result).to eq(grant_resources)
      end

      it "raises InvalidTarget when requesting resources not in the grant" do
        expect do
          described_class.validate!(
            ["https://other.example.com/"],
            grant_resource_indicators: grant_resources,
          )
        end.to raise_error(Doorkeeper::Errors::InvalidTarget)
      end
    end
  end

  describe ".valid?" do
    it "returns true for nil" do
      expect(described_class.valid?(nil)).to be true
    end

    it "returns true for blank array" do
      expect(described_class.valid?([])).to be true
    end

    it "returns true for valid absolute URIs" do
      expect(described_class.valid?(["https://api.example.com/"])).to be true
    end

    it "returns false for URIs with fragments" do
      expect(described_class.valid?(["https://api.example.com/#frag"])).to be false
    end

    it "returns false for relative URIs" do
      expect(described_class.valid?(["/path"])).to be false
    end
  end
end
