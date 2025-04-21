# frozen_string_literal: true

require "spec_helper"

RSpec.describe Doorkeeper::ClientAuthentication::FallbackMethod do
  describe 'matches_request?' do
    it "matches all requests" do
      expect(described_class.matches_request?({})).to be true
    end
  end

  describe 'authenticate' do
    it "returns nil" do
      expect(described_class.authenticate({})).to be_nil
    end
  end
end
