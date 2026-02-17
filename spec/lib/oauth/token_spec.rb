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
      allow(described_class).to receive(:from_params).with(request).and_return("token-value")

      expect(described_class.from_request(request, :from_params)).to eq("token-value")
    end

    # Custom callable extractors are exempt from the multi-method check and
    # keep the historical first-wins selection, so they are never invoked
    # more than once (parity with the exemption client authentication gives
    # its legacy callable extractors).
    it "stops at the first callable that extracts credentials" do
      not_called_method = double
      expect(not_called_method).not_to receive(:call)
      described_class.from_request request, ->(_r) {}, method, not_called_method
    end

    it "returns the credential from extractor method" do
      credentials = described_class.from_request request, method
      expect(credentials).to eq("token-value")
    end

    it "skips methods that extract nothing" do
      credentials = described_class.from_request request, ->(_r) {}, method, ->(_r) { "" }
      expect(credentials).to eq("token-value")
    end

    # RFC 6750 §2: "Clients MUST NOT use more than one method to transmit the
    # token in each request." Every built-in method has to be consulted: a
    # token presented by a method that is never called cannot be detected as
    # a second transmission method.
    it "refuses a request where two built-in methods present different tokens" do
      allow(described_class).to receive(:from_access_token_param).with(request).and_return("token-value")
      allow(described_class).to receive(:from_bearer_param).with(request).and_return("another-token-value")

      expect { described_class.from_request(request, :from_access_token_param, :from_bearer_param) }
        .to raise_error(Doorkeeper::Errors::MultipleAccessTokenMethods)
    end

    # §2 forbids using more than one method, whatever each one carries, and
    # §3.1 lists "repeats the same parameter" right beside the multi-method
    # condition — so the same value presented twice is still two methods.
    it "refuses a request where two built-in methods present the same token" do
      allow(described_class).to receive(:from_access_token_param).with(request).and_return("token-value")
      allow(described_class).to receive(:from_bearer_param).with(request).and_return("token-value")

      expect { described_class.from_request(request, :from_access_token_param, :from_bearer_param) }
        .to raise_error(Doorkeeper::Errors::MultipleAccessTokenMethods)
    end

    it "does not count a token presented by a callable extractor" do
      allow(described_class).to receive(:from_bearer_param).with(request).and_return("another-token-value")

      expect(described_class.from_request(request, method, :from_bearer_param))
        .to eq("token-value")
    end

    # RFC 6750 treats the form-encoded body (§2.2) and the URI query (§2.3) as
    # two distinct transmission methods, but ActionDispatch merges them into a
    # single parameter hash — request_parameters.merge(query_parameters) — so
    # the extractor sees one value and the other token is discarded silently.
    context "when one parameter is transmitted in both the body and the query" do
      def request_with(parameter, query:, body:)
        ActionDispatch::Request.new(
          Rack::MockRequest.env_for(
            "/resource?#{parameter}=#{query}",
            method: "POST",
            params: { parameter.to_s => body },
          ),
        )
      end

      it "refuses conflicting access_token values" do
        request = request_with(:access_token, query: "query-token", body: "body-token")

        expect(request.parameters[:access_token]).to eq("query-token")
        expect { described_class.from_request(request, :from_access_token_param) }
          .to raise_error(Doorkeeper::Errors::MultipleAccessTokenMethods)
      end

      it "refuses conflicting bearer_token values" do
        request = request_with(:bearer_token, query: "query-token", body: "body-token")

        expect { described_class.from_request(request, :from_bearer_param) }
          .to raise_error(Doorkeeper::Errors::MultipleAccessTokenMethods)
      end

      it "refuses the same value carried by both" do
        request = request_with(:access_token, query: "token-value", body: "token-value")

        expect { described_class.from_request(request, :from_access_token_param) }
          .to raise_error(Doorkeeper::Errors::MultipleAccessTokenMethods)
      end

      # The check counts the extractor's own value alongside the two raw
      # sources, so a single parameter must not be counted twice: once as
      # what the extractor read and once as the source it came from.
      it "returns the token when only the query carries it" do
        request = ActionDispatch::Request.new(
          Rack::MockRequest.env_for("/resource?access_token=token-value"),
        )

        expect(described_class.from_request(request, :from_access_token_param))
          .to eq("token-value")
      end

      it "returns the token when only the body carries it" do
        request = ActionDispatch::Request.new(
          Rack::MockRequest.env_for("/resource", method: "POST", params: { "access_token" => "token-value" }),
        )

        expect(described_class.from_request(request, :from_access_token_param))
          .to eq("token-value")
      end
    end

    # A token the extractor reaches by neither raw source — here a path
    # segment, which ActionDispatch merges into #parameters as well — is one
    # transmission method, not two.
    it "returns a token carried only by a path parameter" do
      request = ActionDispatch::Request.new(Rack::MockRequest.env_for("/resource"))
      request.path_parameters = { access_token: "token-value" }

      expect(described_class.from_request(request, :from_access_token_param))
        .to eq("token-value")
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

      let(:method) { ->(_r) { "token" } }

      it "revokes previous refresh_token for a bearer token" do
        access_token = instance_double(Doorkeeper::AccessToken, uses_dpop?: false)
        expect(
          Doorkeeper::AccessToken,
        ).to receive(:by_token).with("token").and_return(access_token)
        expect(access_token).to receive(:revoke_previous_refresh_token!)
        described_class.authenticate double, method
      end

      it "does not revoke previous refresh_token for a dpop token" do
        access_token = instance_double(Doorkeeper::AccessToken, uses_dpop?: true)
        expect(
          Doorkeeper::AccessToken,
        ).to receive(:by_token).with("token").and_return(access_token)
        expect(access_token).not_to receive(:revoke_previous_refresh_token!)
        described_class.authenticate double, method
      end

      it "calls the finder if token was returned" do
        expect(Doorkeeper::AccessToken).to receive(:by_token).with("token")
        described_class.authenticate double, method
      end
    end

    context "when multiple methods are given" do
      it "uses the first method that yields a token and ignores later ones" do
        first  = ->(_r) { "first-token" }
        second = double
        expect(second).not_to receive(:call)

        access_token = double("access token")
        allow(Doorkeeper::AccessToken)
          .to receive(:by_token).with("first-token").and_return(access_token)

        expect(described_class.authenticate(double, first, second)).to eq(access_token)
      end

      it "skips methods that return a blank token" do
        blank = ->(_r) { nil }
        found = ->(_r) { "token" }

        access_token = double("access token")
        allow(Doorkeeper::AccessToken)
          .to receive(:by_token).with("token").and_return(access_token)

        expect(described_class.authenticate(double, blank, found)).to eq(access_token)
      end

      it "returns nil and does not query for a token when no method yields one" do
        blank = ->(_r) { nil }
        expect(Doorkeeper::AccessToken).not_to receive(:by_token)

        expect(described_class.authenticate(double, blank)).to be_nil
      end
    end
  end

  describe ".resolve" do
    it "returns a resolution instance when a token is found" do
      found        = ->(_r) { "token" }
      access_token = double("access token")

      allow(Doorkeeper::AccessToken).to receive(:by_token).with("token").and_return(access_token)

      expect(described_class.resolve(double, found)).to(
        eq(Doorkeeper::OAuth::Token::Resolution.new(found, "token", access_token)),
      )
    end

    it "returns nil when no method yields a token" do
      blank = ->(_r) { nil }

      expect(Doorkeeper::AccessToken).not_to receive(:by_token)

      expect(described_class.resolve(double, blank)).to be_nil
    end

    it "returns nil when a token is found but no access token matches it" do
      found = ->(_r) { "token" }

      allow(Doorkeeper::AccessToken).to receive(:by_token).with("token").and_return(nil)

      expect(described_class.resolve(double, found)).to be_nil
    end
  end
end
