# frozen_string_literal: true

require "spec_helper"
require "jwt"

RSpec.describe Doorkeeper::OAuth::ClientAuthentication::PrivateKeyJwt do
  let(:client_id) { "registered-client-uid" }
  let(:issuer) { "https://as.example.com" }
  let(:rsa_key) { OpenSSL::PKey::RSA.generate(2048) }
  let(:kid) { "test-key" }
  let(:jwk) { JWT::JWK.new(rsa_key.public_key, { kid: kid }) }
  let(:jwks) { { "keys" => [jwk.export] } }
  let(:application) { double("application", jwks: jwks, jwks_uri: nil) }
  let(:client) { instance_double(Doorkeeper::OAuth::Client, application: application) }

  before do
    config_is_set(:issuer, issuer)
    allow(Doorkeeper::OAuth::Client).to receive(:find).and_return(nil)
    allow(Doorkeeper::OAuth::Client).to receive(:find).with(client_id).and_return(client)
    described_class::ReplayGuard.instance.clear
    # Both memos outlive a single example; the jwks one is keyed by URL only,
    # so a jwks_uri reused across examples would otherwise serve stale keys.
    described_class::KeyResolver.jwks_cache.clear
    Doorkeeper::ClientIdMetadata.document_cache.clear
  end

  def build_assertion(claims: {}, key: rsa_key, alg: "RS256", header_kid: kid)
    claims = {
      "iss" => client_id,
      "sub" => client_id,
      "aud" => issuer,
      "exp" => Time.now.to_i + 300,
      "jti" => SecureRandom.hex(8),
    }.merge(claims).compact

    headers = header_kid ? { "kid" => header_kid } : {}
    JWT.encode(claims, key, alg, headers)
  end

  def request_with(assertion, extra_params = {})
    mock_request(
      request_parameters: {
        client_assertion: assertion,
        client_assertion_type: described_class::CLIENT_ASSERTION_TYPE,
      }.merge(extra_params),
    )
  end

  it "declares that it uses no shared secret" do
    expect(described_class.uses_shared_secret?).to be false
  end

  describe ".matches_request?" do
    it "matches a POST with an assertion and the jwt-bearer assertion type" do
      expect(described_class.matches_request?(request_with(build_assertion))).to be true
    end

    it "does not match without a client_assertion" do
      request = mock_request(request_parameters: { client_assertion_type: described_class::CLIENT_ASSERTION_TYPE })

      expect(described_class.matches_request?(request)).to be false
    end

    it "does not match another assertion type" do
      request = mock_request(
        request_parameters: {
          client_assertion: build_assertion,
          client_assertion_type: "urn:ietf:params:oauth:client-assertion-type:saml2-bearer",
        },
      )

      expect(described_class.matches_request?(request)).to be false
    end

    it "does not match without an assertion type" do
      request = mock_request(request_parameters: { client_assertion: build_assertion })

      expect(described_class.matches_request?(request)).to be false
    end

    it "does not match GET requests" do
      request = mock_request(
        request_method: "GET",
        request_parameters: {
          client_assertion: build_assertion,
          client_assertion_type: described_class::CLIENT_ASSERTION_TYPE,
        },
      )

      expect(described_class.matches_request?(request)).to be false
    end
  end

  describe ".authenticate" do
    it "returns pre-authenticated credentials for a valid assertion" do
      credentials = described_class.authenticate(request_with(build_assertion))

      expect(credentials).to be_a(Doorkeeper::ClientAuthentication::VerifiedCredentials)
      expect(credentials.uid).to eq(client_id)
      expect(credentials.secret).to be_nil
      expect(credentials).to be_pre_authenticated
    end

    # A missing dependency is the operator's problem, not the client's, so it
    # must not travel back as an OAuth error: raising outside the
    # Doorkeeper::Errors::DoorkeeperError hierarchy the endpoints translate into
    # error responses is what keeps the message out of the token response body.
    it "raises outside the error hierarchy rendered to clients without the jwt gem" do
      allow(described_class).to receive(:require).with("jwt").and_raise(LoadError)

      expect { described_class.authenticate(request_with(build_assertion)) }
        .to raise_error(LoadError, /requires the 'jwt' gem/)
    end

    it "accepts the token endpoint URL as audience" do
      credentials = described_class.authenticate(
        request_with(build_assertion(claims: { "aud" => "#{issuer}/oauth/token" })),
      )

      expect(credentials).not_to be_nil
    end

    it "accepts the called endpoint's URL as audience" do
      request = request_with(build_assertion)

      credentials = described_class.authenticate(
        request_with(build_assertion(claims: { "aud" => "#{issuer}#{request.path}" })),
      )

      expect(credentials).not_to be_nil
    end

    # The audience is what stops an assertion minted for another authorization
    # server from being accepted here, so it must not be derived from a header
    # the caller controls.
    it "rejects an audience built from the request's Host header" do
      request = request_with(build_assertion)
      audience = request.base_url + request.path

      credentials = described_class.authenticate(request_with(build_assertion(claims: { "aud" => audience })))

      expect(credentials).to be_nil
    end

    context "when the server identifies itself nowhere" do
      before { config_is_set(:issuer, nil) }

      it "falls back to the request URL as audience" do
        request = request_with(build_assertion)
        audience = request.base_url + request.path

        credentials = described_class.authenticate(request_with(build_assertion(claims: { "aud" => audience })))

        expect(credentials).not_to be_nil
      end
    end

    it "accepts a matching client_id parameter next to the assertion" do
      credentials = described_class.authenticate(request_with(build_assertion, client_id: client_id))

      expect(credentials).not_to be_nil
    end

    it "rejects a client_id parameter that contradicts the assertion issuer" do
      credentials = described_class.authenticate(request_with(build_assertion, client_id: "someone-else"))

      expect(credentials).to be_nil
    end

    it "rejects an assertion whose iss and sub differ" do
      credentials = described_class.authenticate(request_with(build_assertion(claims: { "sub" => "someone-else" })))

      expect(credentials).to be_nil
    end

    it "rejects an assertion for an unknown client" do
      credentials = described_class.authenticate(request_with(build_assertion(claims: { "iss" => "ghost", "sub" => "ghost" })))

      expect(credentials).to be_nil
    end

    it "rejects an assertion signed with the wrong key" do
      other_key = OpenSSL::PKey::RSA.generate(2048)

      credentials = described_class.authenticate(request_with(build_assertion(key: other_key)))

      expect(credentials).to be_nil
    end

    it "rejects HMAC-signed assertions even when the jwks carries an oct key" do
      allow(application).to receive(:jwks).and_return(
        "keys" => [jwk.export, { "kty" => "oct", "kid" => "hmac", "k" => Base64.urlsafe_encode64("secret") }],
      )

      credentials = described_class.authenticate(
        request_with(build_assertion(key: "secret", alg: "HS256", header_kid: "hmac")),
      )

      expect(credentials).to be_nil
    end

    it "rejects unsigned assertions" do
      credentials = described_class.authenticate(
        request_with(build_assertion(key: nil, alg: "none", header_kid: nil)),
      )

      expect(credentials).to be_nil
    end

    it "rejects an assertion referencing an unknown kid" do
      credentials = described_class.authenticate(request_with(build_assertion(header_kid: "other-kid")))

      expect(credentials).to be_nil
    end

    it "rejects an expired assertion" do
      credentials = described_class.authenticate(request_with(build_assertion(claims: { "exp" => Time.now.to_i - 10 })))

      expect(credentials).to be_nil
    end

    it "rejects an assertion without exp" do
      credentials = described_class.authenticate(request_with(build_assertion(claims: { "exp" => nil })))

      expect(credentials).to be_nil
    end

    it "rejects an assertion that lives longer than MAX_LIFETIME" do
      too_late = Time.now.to_i + described_class::MAX_LIFETIME + 60

      credentials = described_class.authenticate(request_with(build_assertion(claims: { "exp" => too_late })))

      expect(credentials).to be_nil
    end

    it "rejects an assertion without an audience" do
      credentials = described_class.authenticate(request_with(build_assertion(claims: { "aud" => nil })))

      expect(credentials).to be_nil
    end

    it "rejects an assertion for another audience" do
      credentials = described_class.authenticate(request_with(build_assertion(claims: { "aud" => "https://other.example.com" })))

      expect(credentials).to be_nil
    end

    it "rejects an assertion without a jti" do
      credentials = described_class.authenticate(request_with(build_assertion(claims: { "jti" => nil })))

      expect(credentials).to be_nil
    end

    it "rejects a replayed assertion" do
      assertion = build_assertion

      expect(described_class.authenticate(request_with(assertion))).not_to be_nil
      expect(described_class.authenticate(request_with(assertion))).to be_nil
    end

    it "rejects garbage assertions" do
      expect(described_class.authenticate(request_with("not.a.jwt"))).to be_nil
    end

    # A JWT payload is any JSON value, and the issuer is read before anything
    # is verified — so a payload that is not an object must fail
    # authentication rather than raise out of the token endpoint.
    ["[1, 2]", "42", %("a string")].each do |payload|
      it "rejects an assertion whose payload is #{payload}" do
        segments = [{ "alg" => "RS256" }.to_json, payload, "signature"]
        assertion = segments.map { |segment| Base64.urlsafe_encode64(segment).delete("=") }.join(".")

        expect { expect(described_class.authenticate(request_with(assertion))).to be_nil }
          .not_to raise_error
      end
    end

    it "returns nil when the client publishes no keys" do
      keyless = double("application")
      allow(client).to receive(:application).and_return(keyless)

      expect(described_class.authenticate(request_with(build_assertion))).to be_nil
    end

    it "reads a JSON string jwks attribute" do
      allow(application).to receive(:jwks).and_return({ "keys" => [jwk.export] }.to_json)

      expect(described_class.authenticate(request_with(build_assertion))).not_to be_nil
    end

    # A malformed JWK Set must fail authentication rather than raise a
    # TypeError out of the token endpoint. The last four are keys that only
    # blow up once they are parsed for real: a member that is not valid
    # base64url, and an EC point that is not on its curve — the latter is
    # parsed lazily when a kid is present, so it escapes through the decode
    # path rather than through the JWK Set constructor.
    [
      ["an array", [{ "kty" => "RSA" }]],
      ["a number", 42],
      ["an object whose keys is not an array", { "keys" => { "kid" => "x" } }],
      ["an object whose keys holds non-objects", { "keys" => ["not-a-key"] }],
      ["an object whose keys mixes objects and non-objects", { "keys" => ["junk", { "kty" => "oct", "k" => "x" }] }],
      ["a key with a malformed base64url member", { "keys" => [{ "kty" => "RSA", "n" => "!!!", "e" => "AQAB" }] }],
      ["a kid-bearing key with a malformed base64url member",
       { "keys" => [{ "kty" => "RSA", "kid" => "test-key", "n" => "!!!", "e" => "AQAB" }] },],
      ["an EC point that is not on the curve",
       { "keys" => [{ "kty" => "EC", "crv" => "P-256", "x" => "AA", "y" => "AA" }] },],
      ["a kid-bearing EC point that is not on the curve",
       { "keys" => [{ "kty" => "EC", "crv" => "P-256", "kid" => "test-key", "x" => "AA", "y" => "AA" }] },],
    ].each do |description, value|
      it "returns nil when the application's jwks is #{description}" do
        allow(application).to receive(:jwks).and_return(value)

        expect { expect(described_class.authenticate(request_with(build_assertion))).to be_nil }
          .not_to raise_error
      end
    end

    context "with a client ID metadata document client" do
      let(:client_id) { "https://client.example.com/oauth-client" }

      before do
        config_is_set(:client_id_metadata_documents, true)
        config_is_set(:client_authentication, %i[client_secret_basic client_secret_post none private_key_jwt])
        allow(Resolv).to receive(:getaddresses).and_return(["93.184.216.34"])
        allow(Doorkeeper::OAuth::Client).to receive(:find).and_call_original
      end

      def stub_document(document_attributes)
        stub_request(:get, client_id).to_return(
          status: 200,
          body: {
            "client_id" => client_id,
            "redirect_uris" => ["https://app.example.com/callback"],
            "token_endpoint_auth_method" => "private_key_jwt",
          }.merge(document_attributes).to_json,
        )
      end

      it "verifies against the document's inline jwks" do
        stub_document("jwks" => jwks)

        credentials = described_class.authenticate(request_with(build_assertion))

        expect(credentials).not_to be_nil
        expect(credentials.uid).to eq(client_id)
      end

      it "verifies against keys fetched from the document's jwks_uri" do
        jwks_uri = "https://client.example.com/jwks.json"
        stub_document("jwks_uri" => jwks_uri)
        stub_request(:get, jwks_uri).to_return(status: 200, body: jwks.to_json)

        expect(described_class.authenticate(request_with(build_assertion))).not_to be_nil
      end

      it "fetches the jwks_uri once across several authentications" do
        jwks_uri = "https://client.example.com/jwks.json"
        stub_document("jwks_uri" => jwks_uri)
        stub_request(:get, jwks_uri).to_return(status: 200, body: jwks.to_json)

        2.times { expect(described_class.authenticate(request_with(build_assertion))).not_to be_nil }

        expect(a_request(:get, jwks_uri)).to have_been_made.once
      end

      it "does not cache a malformed jwks_uri response" do
        jwks_uri = "https://client.example.com/jwks.json"
        stub_document("jwks_uri" => jwks_uri)
        stub_request(:get, jwks_uri).to_return(status: 200, body: "[]")

        expect(described_class.authenticate(request_with(build_assertion))).to be_nil
        expect(described_class.authenticate(request_with(build_assertion))).to be_nil

        expect(a_request(:get, jwks_uri)).to have_been_made.twice
      end

      # Resolving a URL client_id materializes an application row, so it must
      # not happen for a request that fails to authenticate.
      it "does not create an application row when the assertion does not verify" do
        stub_document("jwks" => jwks)
        assertion = build_assertion(key: OpenSSL::PKey::RSA.generate(2048))

        expect { expect(described_class.authenticate(request_with(assertion))).to be_nil }
          .not_to change(Doorkeeper::Application, :count).from(0)
      end

      it "does not create an application row for an unsigned assertion" do
        stub_document("jwks" => jwks)
        assertion = JWT.encode(
          {
            "iss" => client_id,
            "sub" => client_id,
            "aud" => issuer,
            "exp" => Time.now.to_i + 300,
            "jti" => SecureRandom.hex(8),
          },
          nil,
          "none",
        )

        expect { expect(described_class.authenticate(request_with(assertion))).to be_nil }
          .not_to change(Doorkeeper::Application, :count).from(0)
      end

      it "returns nil without raising when the document's jwks_uri serves a JSON array" do
        jwks_uri = "https://client.example.com/jwks.json"
        stub_document("jwks_uri" => jwks_uri)
        stub_request(:get, jwks_uri).to_return(status: 200, body: [jwk.export].to_json)

        expect { expect(described_class.authenticate(request_with(build_assertion))).to be_nil }
          .not_to raise_error
      end

      it "rejects the assertion when the jwks_uri is not https" do
        stub_document("jwks_uri" => "http://client.example.com/jwks.json")

        expect(described_class.authenticate(request_with(build_assertion))).to be_nil
      end

      it "rejects the assertion when the document has no keys" do
        stub_document({})

        expect(described_class.authenticate(request_with(build_assertion))).to be_nil
      end
    end
  end
end
