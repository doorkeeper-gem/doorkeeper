# frozen_string_literal: true

require "spec_helper"

RSpec.describe Doorkeeper::OAuth::ClientAuthentication::ClientSecretBasic do
  describe ".matches_request?" do
    it "matches if the request has basic authorization" do
      request = mock_request(
        authorization: ActionController::HttpAuthentication::Basic.encode_credentials("username", "password"),
      )

      expect(described_class.matches_request?(request)).to be true
    end

    it "doesn't match if the request has bearer authorization" do
      request = mock_request(authorization: "Bearer foobar")

      expect(described_class.matches_request?(request)).not_to be true
    end

    it "doesn't match if the request has no authorization" do
      request = mock_request

      expect(described_class.matches_request?(request)).not_to be true
    end

    it "doesn't match a malformed header that merely starts with 'basic' but has no credentials" do
      request = mock_request(authorization: "basicgarbage")

      expect(described_class.matches_request?(request)).not_to be true
    end

    it "doesn't match a 'Basic ' header with an empty payload" do
      request = mock_request(authorization: "Basic ")

      expect(described_class.matches_request?(request)).not_to be true
    end

    it "doesn't match when the decoded payload has a blank client_id" do
      request = mock_request(authorization: "Basic #{Base64.strict_encode64(":secret")}")

      expect(described_class.matches_request?(request)).not_to be true
    end

    it "matches a colon-less payload that decodes to a non-blank client_id" do
      request = mock_request(authorization: "Basic #{Base64.strict_encode64("client_id")}")

      expect(described_class.matches_request?(request)).to be true
    end

    it "matches a Basic auth attempt even when the decoded secret is empty" do
      request = mock_request(
        authorization: ActionController::HttpAuthentication::Basic.encode_credentials("client_id", ""),
      )

      expect(described_class.matches_request?(request)).to be true
    end
  end

  describe ".authenticate" do
    it "returns credentials using the values from the authorization header" do
      request = mock_request(
        authorization: ActionController::HttpAuthentication::Basic.encode_credentials("client_id", "client_secret"),
      )

      credentials = described_class.authenticate(request)

      expect(credentials).to be_instance_of(Doorkeeper::ClientAuthentication::Credentials)
      expect(credentials.uid).to eq("client_id")
      expect(credentials.secret).to eq("client_secret")
    end

    it "returns credentials with a blank secret when the client_secret is missing" do
      request = mock_request(
        authorization: ActionController::HttpAuthentication::Basic.encode_credentials("client_id", ""),
      )

      credentials = described_class.authenticate(request)

      expect(credentials).to be_instance_of(Doorkeeper::ClientAuthentication::Credentials)
      expect(credentials.uid).to eq("client_id")
      expect(credentials.secret).to be_blank
    end

    it "returns nil when the header decodes to a blank client_id" do
      request = mock_request(authorization: "Basic #{Base64.strict_encode64(":secret")}")

      expect(described_class.authenticate(request)).to be_nil
    end
  end
end
