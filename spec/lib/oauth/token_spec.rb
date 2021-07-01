# frozen_string_literal: true

require "spec_helper"

module Doorkeeper
  unless defined?(AccessToken)
    class AccessToken
    end
  end
end

RSpec.describe Doorkeeper::OAuth::Token do
  describe ".from_request" do
    let(:request) { double.as_null_object }

    let(:method) do
      ->(*) { "token-value" }
    end

    it "accepts anything that responds to #call" do
      expect(method).to receive(:call).with(request)
      described_class.from_request request, method
    end

    it "delegates methods received as symbols to described_class class" do
      expect(described_class).to receive(:from_params).with(request)
      described_class.from_request request, :from_params
    end

    it "stops at the first credentials found" do
      not_called_method = double
      expect(not_called_method).not_to receive(:call)
      described_class.from_request request, ->(_r) {}, method, not_called_method
    end

    it "returns the credential from extractor method" do
      credentials = described_class.from_request request, method
      expect(credentials).to eq("token-value")
    end

    it "customize the returned credentials" do
      Doorkeeper.configure do
        orm DOORKEEPER_ORM
        customized_token { |token| "#{token}_custom_part" }
      end

      credentials = described_class.from_request request, method
      expect(credentials).to eq("token-value_custom_part")
    end
  end

  describe ".from_access_token_param" do
    it "returns token from access_token parameter" do
      request = double parameters: { access_token: "some-token" }
      token   = described_class.from_access_token_param(request)
      expect(token).to eq("some-token")
    end
  end

  describe ".from_bearer_param" do
    it "returns token from bearer_token parameter" do
      request = double parameters: { bearer_token: "some-token" }
      token   = described_class.from_bearer_param(request)
      expect(token).to eq("some-token")
    end
  end

  describe ".from_bearer_authorization" do
    it "returns token from capitalized authorization bearer" do
      request = double authorization: "Bearer SomeToken"
      token   = described_class.from_bearer_authorization(request)
      expect(token).to eq("SomeToken")
    end

    it "returns token from lowercased authorization bearer" do
      request = double authorization: "bearer SomeToken"
      token   = described_class.from_bearer_authorization(request)
      expect(token).to eq("SomeToken")
    end

    it "does not return token if authorization is not bearer" do
      request = double authorization: "MAC SomeToken"
      token   = described_class.from_bearer_authorization(request)
      expect(token).to be_blank
    end
  end

  describe ".from_basic_authorization" do
    it "returns token from capitalized authorization basic" do
      request = double authorization: "Basic #{Base64.encode64 "SomeToken:"}"
      token   = described_class.from_basic_authorization(request)
      expect(token).to eq("SomeToken")
    end

    it "returns token from lowercased authorization basic" do
      request = double authorization: "basic #{Base64.encode64 "SomeToken:"}"
      token   = described_class.from_basic_authorization(request)
      expect(token).to eq("SomeToken")
    end

    it "does not return token if authorization is not basic" do
      request = double authorization: "MAC #{Base64.encode64 "SomeToken:"}"
      token   = described_class.from_basic_authorization(request)
      expect(token).to be_blank
    end
  end

  describe ".authenticate" do
    context "when refresh tokens are disabled (default)" do
      context "when refresh tokens are enabled" do
        it "does not revoke previous refresh_token if token was found" do
          token = ->(_r) { "token" }
          expect(
            Doorkeeper::AccessToken,
          ).to receive(:by_token).with("token").and_return(token)
          expect(token).not_to receive(:revoke_previous_refresh_token!)
          described_class.authenticate double, token
        end
      end

      it "calls the finder if token was returned" do
        token = ->(_r) { "token" }
        expect(Doorkeeper::AccessToken).to receive(:by_token).with("token")
        described_class.authenticate double, token
      end
    end

    context "when token hashing is enabled" do
      include_context "with token hashing enabled"

      let(:hashed_token) { hashed_or_plain_token_func.call("token") }
      let(:token) { ->(_r) { "token" } }

      it "searches with the hashed token" do
        expect(
          Doorkeeper::AccessToken,
        ).to receive(:find_by).with(token: hashed_token).and_return(token)
        described_class.authenticate double, token
      end
    end

    context "when refresh tokens are enabled" do
      before do
        Doorkeeper.configure do
          orm DOORKEEPER_ORM
          use_refresh_token
        end
      end

      it "revokes previous refresh_token if token was found" do
        token = ->(_r) { "token" }
        expect(
          Doorkeeper::AccessToken,
        ).to receive(:by_token).with("token").and_return(token)
        expect(token).to receive(:revoke_previous_refresh_token!)
        described_class.authenticate double, token
      end

      it "calls the finder if token was returned" do
        token = ->(_r) { "token" }
        expect(Doorkeeper::AccessToken).to receive(:by_token).with("token")
        described_class.authenticate double, token
      end
    end
  end
end
