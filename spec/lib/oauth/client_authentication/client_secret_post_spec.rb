# frozen_string_literal: true

require "spec_helper"

RSpec.describe Doorkeeper::OAuth::ClientAuthentication::ClientSecretPost do
  describe 'matches_request?' do
    it "matches if the request doesn't have authorization" do
      request = mock_request request_parameters: {
        client_id: '1234',
        client_secret: '5678'
      }

      expect(described_class.matches_request?(request)).to be true
    end

    it "doesn't match if the request is missing client_secret" do
      request = mock_request request_parameters: {
        client_id: '1234'
      }

      expect(described_class.matches_request?(request)).to_not be true
    end

    it "doesn't match if the parameters are in the query parameters" do
      request = mock_request query_parameters: {
        client_id: '1234',
        client_secret: '5678'
      }

      expect(described_class.matches_request?(request)).to_not be true
    end
  end

  describe 'authenticate' do
    it "returns credentials using the values from the request parameters" do
      request = mock_request request_parameters: {
        client_id: 'client_id',
        client_secret: 'client_secret'
      }

      credentials = described_class.authenticate(request)

      expect(credentials).to be_instance_of(Doorkeeper::ClientAuthentication::Credentials)
      expect(credentials.uid).to eq("client_id")
      expect(credentials.secret).to eq("client_secret")
    end
  end
end
