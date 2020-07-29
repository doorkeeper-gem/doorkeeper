# frozen_string_literal: true

require "spec_helper"

RSpec.describe Doorkeeper::OAuth::TokenResponse do
  subject(:response) { described_class.new(double.as_null_object) }

  it "includes access token response headers" do
    headers = response.headers
    expect(headers.fetch("Cache-Control")).to eq("no-store")
    expect(headers.fetch("Pragma")).to eq("no-cache")
  end

  it "status is ok" do
    expect(response.status).to eq(:ok)
  end

  describe ".body" do
    subject(:body) { described_class.new(access_token).body }

    let(:access_token) do
      double :access_token,
             plaintext_token: "some-token",
             expires_in: "3600",
             expires_in_seconds: "300",
             scopes_string: "two scopes",
             plaintext_refresh_token: "some-refresh-token",
             token_type: "Bearer",
             created_at: 0
    end

    it "includes :access_token" do
      expect(body["access_token"]).to eq("some-token")
    end

    it "includes :token_type" do
      expect(body["token_type"]).to eq("Bearer")
    end

    # expires_in_seconds is returned as `expires_in` in order to match
    # the OAuth spec (section 4.2.2)
    it "includes :expires_in" do
      expect(body["expires_in"]).to eq("300")
    end

    it "includes :scope" do
      expect(body["scope"]).to eq("two scopes")
    end

    it "includes :refresh_token" do
      expect(body["refresh_token"]).to eq("some-refresh-token")
    end

    it "includes :created_at" do
      expect(body["created_at"]).to eq(0)
    end
  end

  describe ".body filters out empty values" do
    subject(:body) { described_class.new(access_token).body }

    let(:access_token) do
      double :access_token,
             plaintext_token: "some-token",
             expires_in_seconds: "",
             scopes_string: "",
             plaintext_refresh_token: "",
             token_type: "Bearer",
             created_at: 0
    end

    it "includes :expires_in" do
      expect(body["expires_in"]).to be_nil
    end

    it "includes :scope" do
      expect(body["scope"]).to be_nil
    end

    it "includes :refresh_token" do
      expect(body["refresh_token"]).to be_nil
    end
  end
end
