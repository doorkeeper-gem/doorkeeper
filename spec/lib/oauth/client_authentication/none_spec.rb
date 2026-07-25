# frozen_string_literal: true

require "spec_helper"

RSpec.describe Doorkeeper::OAuth::ClientAuthentication::None do
  it "declares that it uses no shared secret" do
    expect(described_class.uses_shared_secret?).to be false
  end

  describe ".matches_request?" do
    it "matches if the request body has a client_id but no client_secret" do
      request = mock_request(request_parameters: { client_id: "1234" })

      expect(described_class.matches_request?(request)).to be true
    end

    it "doesn't match if the request has a client_secret" do
      request = mock_request(request_parameters: { client_id: "1234", client_secret: "5678" })

      expect(described_class.matches_request?(request)).not_to be true
    end

    it "doesn't match if the request has authorization" do
      request = mock_request(
        request_parameters: { client_id: "1234" },
        authorization: ActionController::HttpAuthentication::Basic.encode_credentials("username", "password"),
      )

      expect(described_class.matches_request?(request)).not_to be true
    end

    it "matches if the Authorization header is a Bearer token (endpoint protection, not client auth)" do
      # A Bearer credential authorizes access to the endpoint itself (e.g. a
      # bearer-protected introspection endpoint, RFC 7662 §2.1) rather than
      # authenticating the client, so it must not suppress the none strategy
      # for a public client identifying itself with a body client_id.
      request = mock_request(
        request_parameters: { client_id: "1234" },
        authorization: "Bearer some-token",
      )

      expect(described_class.matches_request?(request)).to be true
    end

    it "matches a Bearer header with irregular whitespace" do
      request = mock_request(
        request_parameters: { client_id: "1234" },
        authorization: "  Bearer   some-token",
      )

      expect(described_class.matches_request?(request)).to be true
    end

    it "doesn't accept a line break between the scheme and the token" do
      # Only spaces and tabs stand between the scheme and the token, so a
      # line break in that position doesn't make a bearer credential.
      request = mock_request(
        request_parameters: { client_id: "1234" },
        authorization: "Bearer\nBasic dXNlcjpwYXNzd29yZA==",
      )

      expect(described_class.matches_request?(request)).not_to be true
    end

    it "doesn't match a Bearer scheme preceded by a line break" do
      request = mock_request(
        request_parameters: { client_id: "1234" },
        authorization: "\nBearer some-token",
      )

      expect(described_class.matches_request?(request)).not_to be true
    end

    it "doesn't match a Bearer scheme with no token" do
      # RFC 6750 §2.1: a bearer credential carries at least one token
      # character after the scheme, so a bare "Bearer " is not a bearer
      # token and must not be exempted.
      request = mock_request(
        request_parameters: { client_id: "1234" },
        authorization: "Bearer ",
      )

      expect(described_class.matches_request?(request)).not_to be true
    end

    it "doesn't match if the request has a non-Bearer Authorization header (e.g. Digest)" do
      request = mock_request(
        request_parameters: { client_id: "1234" },
        authorization: "Digest username=\"a\"",
      )

      expect(described_class.matches_request?(request)).not_to be true
    end

    it "matches if the Authorization header is present but empty" do
      request = mock_request(request_parameters: { client_id: "1234" }, authorization: "")

      expect(described_class.matches_request?(request)).to be true
    end

    it "doesn't match if the request is not a POST" do
      request = mock_request(request_parameters: { client_id: "1234" }, request_method: "GET")

      expect(described_class.matches_request?(request)).not_to be true
    end
  end

  describe ".authenticate" do
    it "returns credentials using the client_id from the request body, without a secret" do
      request = mock_request(request_parameters: { client_id: "client_id" })

      credentials = described_class.authenticate(request)

      expect(credentials).to be_instance_of(Doorkeeper::ClientAuthentication::Credentials)
      expect(credentials.uid).to eq("client_id")
      expect(credentials.secret).to be_nil
    end

    it "ignores the client_secret if set" do
      request = mock_request(request_parameters: { client_id: "client_id", client_secret: "client_secret" })

      credentials = described_class.authenticate(request)

      expect(credentials).to be_instance_of(Doorkeeper::ClientAuthentication::Credentials)
      expect(credentials.uid).to eq("client_id")
      expect(credentials.secret).to be_nil
    end
  end
end
