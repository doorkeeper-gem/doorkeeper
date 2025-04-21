# frozen_string_literal: true

require "spec_helper"

RSpec.describe Doorkeeper::OAuth::ClientAuthentication::ClientSecretPost do
  describe 'matches_request?' do
    it "matches if the request doesn't have authorization" do
      request = mock_request({
        client_id: '1234',
        client_secret: '5678'
      })

      expect(described_class.matches_request?(request)).to be true
    end

    it "doesn't match if the request is missing client_secret" do
      request = mock_request({
        client_id: '1234'
      })

      expect(described_class.matches_request?(request)).to_not be true
    end
  end
end
