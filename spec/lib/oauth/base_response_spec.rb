# frozen_string_literal: true

require "spec_helper"

RSpec.describe Doorkeeper::OAuth::BaseResponse do
  subject(:response) do
    described_class.new
  end

  describe "#body" do
    it "returns an empty Hash" do
      expect(response.body).to eq({})
    end
  end

  describe "#description" do
    it "returns an empty String" do
      expect(response.description).to eq("")
    end
  end

  describe "#headers" do
    it "returns an empty Hash" do
      expect(response.headers).to eq({})
    end
  end

  describe "#redirectable?" do
    it "returns false" do
      expect(response.redirectable?).to eq(false)
    end
  end

  describe "#redirect_uri" do
    it "returns an empty String" do
      expect(response.redirect_uri).to eq("")
    end
  end

  describe "#status" do
    it "returns :ok" do
      expect(response.status).to eq(:ok)
    end
  end
end
