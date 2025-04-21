# frozen_string_literal: true

require "spec_helper"

RSpec.describe Doorkeeper::OAuth::ClientAuthentication::ClientSecretBasic do
  describe 'matches_request?' do
    it "matches if the request has basic authorization" do
      request = mock_request({}, ActionController::HttpAuthentication::Basic.encode_credentials('username', 'password'))

      expect(described_class.matches_request?(request)).to be true
    end

    it "doesn't match if the request has bearer authorization" do
      request = mock_request({}, "Bearer foobar")

      expect(described_class.matches_request?(request)).to_not be true
    end
  end
end
