# frozen_string_literal: true

require "spec_helper"

RSpec.describe Doorkeeper::OAuth::ClientAuthentication::None do
  describe 'matches_request?' do
    it "matches if the request doesn't have authorization or client_secret" do
      request = mock_request({
        client_id: '1234'
      })

      expect(described_class.matches_request?(request)).to be true
    end

    it "doesn't match if the request has client_secret" do
      request = mock_request({
        client_id: '1234',
        client_secret: "5678"
      })

      expect(described_class.matches_request?(request)).to_not be true
    end

    it "doesn't match if the request has authorization" do
      request = mock_request({
        client_id: '1234'
      }, ActionController::HttpAuthentication::Basic.encode_credentials('username', 'password'))

      expect(described_class.matches_request?(request)).to_not be true
    end
  end

  describe 'authenticate' do
    it "returns credentials using the values from the request parameters, without a secret" do
      request = mock_request({
        client_id: 'client_id'
      })

      credentials = described_class.authenticate(request)

      expect(credentials).to be_instance_of(Doorkeeper::ClientAuthentication::Credentials)
      expect(credentials.uid).to eq("client_id")
      expect(credentials.secret).to be_nil
    end

    it "ignores the client_secret if set" do
      request = mock_request({
        client_id: 'client_id',
        client_secret: 'client_secret'
      })

      credentials = described_class.authenticate(request)

      expect(credentials).to be_instance_of(Doorkeeper::ClientAuthentication::Credentials)
      expect(credentials.uid).to eq("client_id")
      expect(credentials.secret).to be_nil
    end
  end
end
