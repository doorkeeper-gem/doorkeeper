# frozen_string_literal: true

require "spec_helper"

RSpec.describe Doorkeeper::OAuth::ClientAuthentication::ClientSecretBasic do
  describe 'matches_request?' do
    it "matches if the request has basic authorization" do
      request = mock_request authorization: ActionController::HttpAuthentication::Basic.encode_credentials('username', 'password')

      expect(described_class.matches_request?(request)).to be true
    end

    it "doesn't match if the request has bearer authorization" do
      request = mock_request authorization: "Bearer foobar"

      expect(described_class.matches_request?(request)).to_not be true
    end
  end

  describe 'authenticate' do
    it "returns credentials using the values from the authorization header" do
      request = mock_request authorization: ActionController::HttpAuthentication::Basic.encode_credentials('client_id', 'client_secret')

      credentials = described_class.authenticate(request)

      expect(credentials).to be_instance_of(Doorkeeper::ClientAuthentication::Credentials)
      expect(credentials.uid).to eq("client_id")
      expect(credentials.secret).to eq("client_secret")
    end

    it "returns nil if the client_secret is missing from the authorization header" do
      request = mock_request authorization: ActionController::HttpAuthentication::Basic.encode_credentials('client_id', '')

      credentials = described_class.authenticate(request)

      expect(credentials).to be_nil
    end
  end
end
