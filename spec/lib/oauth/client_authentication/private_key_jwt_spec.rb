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
  end

  # JWT.encode refuses to build a token whose exp is not a NumericDate, so an
  # assertion carrying one has to be signed by hand.
  def sign_raw(payload, key: rsa_key)
    sign_raw_json(payload.to_json, key: key)
  end

  # A payload no JSON generator would emit — an overflowing exponent, say —
  # has to be handed over as raw JSON rather than as a Ruby Hash.
  def sign_raw_json(payload_json, key: rsa_key)
    segments = [
      Base64.urlsafe_encode64({ "alg" => "RS256", "typ" => "JWT", "kid" => kid }.to_json, padding: false),
      Base64.urlsafe_encode64(payload_json, padding: false),
    ]
    signature = key.sign(OpenSSL::Digest.new("SHA256"), segments.join("."))

    (segments << Base64.urlsafe_encode64(signature, padding: false)).join(".")
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

  def request_with(assertion, extra_params = {}, path: "/oauth/token")
    mock_request(
      path: path,
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

    # doorkeeper-jwt defines Doorkeeper::JWT, which shadows the jwt gem for
    # any bare JWT reference made inside the Doorkeeper module — every gem
    # reference in this class must be written ::JWT to survive that.
    context "when doorkeeper-jwt's Doorkeeper::JWT module is defined" do
      before do
        stub_const("Doorkeeper::JWT", Module.new)
      end

      it "still authenticates a valid assertion" do
        credentials = described_class.authenticate(request_with(build_assertion))

        expect(credentials).to be_a(Doorkeeper::ClientAuthentication::VerifiedCredentials)
        expect(credentials.uid).to eq(client_id)
      end

      it "still rejects a malformed assertion without raising" do
        expect(described_class.authenticate(request_with("not-a-jwt"))).to be_nil
      end
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

    # An endpoint other than the token endpoint, so this genuinely exercises
    # the request-path audience rather than passing on the issuer or the
    # token endpoint URL that the examples above already accept.
    it "accepts the called endpoint's URL as audience" do
      credentials = described_class.authenticate(
        request_with(build_assertion(claims: { "aud" => "#{issuer}/oauth/revoke" }), path: "/oauth/revoke"),
      )

      expect(credentials).not_to be_nil
    end

    it "rejects an assertion minted for a different endpoint of this server" do
      credentials = described_class.authenticate(
        request_with(build_assertion(claims: { "aud" => "#{issuer}/oauth/authorize" }), path: "/oauth/revoke"),
      )

      expect(credentials).to be_nil
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
      credentials = described_class.authenticate(request_with(build_assertion, { client_id: client_id }))

      expect(credentials).not_to be_nil
    end

    it "rejects a client_id parameter that contradicts the assertion issuer" do
      credentials = described_class.authenticate(request_with(build_assertion, { client_id: "someone-else" }))

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

    # Verifying an assertion needs no private parameter, so a key set that
    # publishes one belongs to a client that has disclosed its own credential.
    # A model storing what JWT::JWK#export returns hands the Hash back keyed
    # by symbols, so the filter has to look for both spellings.
    it "rejects an assertion verified by a key published with its private parameters" do
      allow(application).to receive(:jwks).and_return(
        keys: [JWT::JWK.new(rsa_key, { kid: kid }).export(include_private: true)],
      )

      expect(described_class.authenticate(request_with(build_assertion))).to be_nil
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

    # The kid requirement is enforced by the jwt gem's JWKS key finder; this
    # example pins it so a change of that gem default cannot silently void
    # the documented requirement.
    it "rejects a validly signed assertion without a kid header" do
      expect(described_class.authenticate(request_with(build_assertion(header_kid: nil)))).to be_nil
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

    # RFC 7519 §4.1.4 defines exp as a NumericDate — a number. The jwt gem
    # validates the type when encoding but not when decoding, where its
    # expiration check casts with to_i — so without an explicit type check a
    # string exp would authenticate. Signed by hand because JWT.encode
    # refuses to mint such an assertion.
    it "rejects a validly signed assertion whose exp is a numeric string" do
      claims = {
        "iss" => client_id, "sub" => client_id, "aud" => issuer,
        "exp" => (Time.now.to_i + 300).to_s, "jti" => "string-exp",
      }
      segments = [{ "alg" => "RS256", "kid" => kid }.to_json, claims.to_json].map do |segment|
        Base64.urlsafe_encode64(segment).delete("=")
      end
      signing_input = segments.join(".")
      signature = rsa_key.sign(OpenSSL::Digest.new("SHA256"), signing_input)
      assertion = "#{signing_input}.#{Base64.urlsafe_encode64(signature).delete("=")}"

      expect(described_class.authenticate(request_with(assertion))).to be_nil
    end

    # The jwt gem casts exp and nbf with to_i while verifying, which raises
    # NoMethodError — not a JWT::DecodeError — for any other JSON type, so
    # such an assertion would escape the rescue around that decode and reach
    # the endpoint as a 500. The signature is valid, which under Client ID
    # Metadata Documents anyone can arrange.
    %w[exp nbf].each do |claim|
      [{}, [1], true].each do |value|
        it "rejects a validly signed assertion whose #{claim} is #{value.class} without raising" do
          payload = {
            "iss" => client_id, "sub" => client_id, "aud" => issuer,
            "exp" => Time.now.to_i + 300, "jti" => SecureRandom.hex(8),
          }.merge(claim => value)

          expect { expect(described_class.authenticate(request_with(sign_raw(payload)))).to be_nil }
            .not_to raise_error
        end
      end
    end

    it "rejects an assertion whose exp is an absurdly large integer" do
      credentials = described_class.authenticate(request_with(build_assertion(claims: { "exp" => 10**100 })))

      expect(credentials).to be_nil
    end

    # Infinity is not valid JSON, so such a payload already fails to decode —
    # pinned here so a laxer JSON parser in a future jwt gem cannot let it
    # reach the arithmetic on exp.
    it "rejects an assertion whose payload smuggles exp: Infinity" do
      payload = %({"iss":"#{client_id}","sub":"#{client_id}","aud":"#{issuer}","exp":Infinity,"jti":"x"})
      segments = [{ "alg" => "RS256", "kid" => kid }.to_json, payload, "signature"]
      assertion = segments.map { |segment| Base64.urlsafe_encode64(segment).delete("=") }.join(".")

      expect { expect(described_class.authenticate(request_with(assertion))).to be_nil }
        .not_to raise_error
    end

    # An Infinity literal is not valid JSON, but an exponent too large for a
    # Float is: JSON.parse turns 1e400 into Float::INFINITY, which is Numeric.
    # The jwt gem then casts exp and nbf with to_i, raising FloatDomainError —
    # a RangeError, so not covered by the rescue around the verifying decode.
    # The signature is valid, which under Client ID Metadata Documents anyone
    # who can host a document can arrange.
    { "exp" => "1e400", "nbf" => "-1e400" }.each do |claim, literal|
      it "rejects a validly signed assertion whose #{claim} overflows to Infinity" do
        claims = {
          "iss" => client_id, "sub" => client_id, "aud" => issuer,
          "exp" => Time.now.to_i + 300, "jti" => SecureRandom.hex(8),
        }.merge(claim => "OVERFLOW")
        payload = claims.to_json.sub('"OVERFLOW"', literal)

        expect { expect(described_class.authenticate(request_with(sign_raw_json(payload)))).to be_nil }
          .not_to raise_error
      end
    end

    it "accepts an assertion whose exp is a finite float NumericDate" do
      credentials = described_class.authenticate(
        request_with(build_assertion(claims: { "exp" => Time.now.to_f.floor + 300.5 })),
      )

      expect(credentials).not_to be_nil
    end

    context "when the host application globally disabled expiration checking" do
      around do |example|
        original = JWT.configuration.decode.verify_expiration
        JWT.configuration.decode.verify_expiration = false
        example.run
      ensure
        JWT.configuration.decode.verify_expiration = original
      end

      it "still rejects an expired assertion" do
        credentials = described_class.authenticate(
          request_with(build_assertion(claims: { "exp" => Time.now.to_i - 10 })),
        )

        expect(credentials).to be_nil
      end
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

    # The replay guard holds an entry per assertion for up to MAX_LIFETIME, so
    # an unbounded jti would let a client choose what each of those costs.
    it "rejects an assertion whose jti is longer than the guard will remember" do
      jti = "a" * (described_class::MAX_JTI_LENGTH + 1)

      expect(described_class.authenticate(request_with(build_assertion(claims: { "jti" => jti })))).to be_nil
    end

    it "accepts an assertion whose jti is exactly at the limit" do
      jti = "a" * described_class::MAX_JTI_LENGTH

      expect(described_class.authenticate(request_with(build_assertion(claims: { "jti" => jti })))).not_to be_nil
    end

    it "rejects a replayed assertion" do
      assertion = build_assertion

      expect(described_class.authenticate(request_with(assertion))).not_to be_nil
      expect(described_class.authenticate(request_with(assertion))).to be_nil
    end

    it "tracks jti replay through a configured custom replay guard" do
      guard = double("replay guard")
      expect(guard).to receive(:first_use?)
        .with(a_string_including(client_id), expires_at: kind_of(Integer))
        .twice
        .and_return(true, false)
      config_is_set(:private_key_jwt_replay_guard, guard)

      assertion = build_assertion

      expect(described_class.authenticate(request_with(assertion))).not_to be_nil
      expect(described_class.authenticate(request_with(assertion))).to be_nil
    end

    # A guard keyed by a bare "client_id:jti" cannot tell those two apart, so
    # one client could burn the jti of another whose id it is a prefix of —
    # different tenants, on a host that serves several clients.
    it "keeps one client from burning the jti of a client sharing its prefix" do
      other_id = "#{client_id}:suffix"
      other = instance_double(Doorkeeper::OAuth::Client, application: application)
      allow(Doorkeeper::OAuth::Client).to receive(:find).with(other_id).and_return(other)

      first = build_assertion(claims: { "jti" => "suffix:shared" })
      second = build_assertion(claims: { "iss" => other_id, "sub" => other_id, "jti" => "shared" })

      expect(described_class.authenticate(request_with(first))).not_to be_nil
      expect(described_class.authenticate(request_with(second))).not_to be_nil
    end

    it "resolves a jwks_uri through a configured custom jwks cache" do
      jwks_uri = "https://client.example.com/jwks.json"
      allow(application).to receive_messages(jwks: nil, jwks_uri: jwks_uri)
      cache = double("jwks cache")
      allow(cache).to receive(:fetch).with(jwks_uri).and_return(jwks)
      config_is_set(:private_key_jwt_jwks_cache, cache)

      expect(described_class.authenticate(request_with(build_assertion))).not_to be_nil
    end

    it "rejects garbage assertions" do
      expect(described_class.authenticate(request_with("not.a.jwt"))).to be_nil
    end

    # URI.parse("https:foo") is a URI::HTTPS with a nil host: it passes the
    # scheme check yet must fail authentication, not raise an ArgumentError
    # out of the token endpoint when the nil host reaches the resolver.
    it "rejects the assertion when the jwks_uri has no host" do
      allow(application).to receive_messages(jwks: nil, jwks_uri: "https:foo")

      expect { expect(described_class.authenticate(request_with(build_assertion))).to be_nil }
        .not_to raise_error
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

    # A JWK Set may carry members that are not strings: "ext" is a boolean in
    # anything WebCrypto exports, which is what a browser client publishes.
    # Hardening against the member types the jwt gem chokes on must not be
    # done by dropping such keys.
    it "accepts a WebCrypto-style key carrying non-string members" do
      allow(application).to receive(:jwks)
        .and_return({ "keys" => [jwk.export.merge("ext" => true, "key_ops" => ["verify"])] })

      expect(described_class.authenticate(request_with(build_assertion))).not_to be_nil
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
      # RFC 7517 gives every JWK member a string (or array of strings) value.
      # The jwt gem indexes into them as such, so any other JSON type raises
      # NoMethodError — neither a JWT error nor an OpenSSL one.
      ["a key whose member is a number", { "keys" => [{ "kty" => "RSA", "n" => 123, "e" => "AQAB" }] }],
      ["a key whose member is an object", { "keys" => [{ "kty" => "RSA", "n" => { "a" => 1 }, "e" => "AQAB" }] }],
      ["a key whose member is an array", { "keys" => [{ "kty" => "RSA", "n" => ["AA"], "e" => "AQAB" }] }],
      ["a key whose member is null", { "keys" => [{ "kty" => "RSA", "n" => nil, "e" => "AQAB" }] }],
      ["a kid-bearing key whose member is a number",
       { "keys" => [{ "kty" => "RSA", "kid" => "test-key", "n" => 123, "e" => "AQAB" }] },],
      ["only symmetric keys", { "keys" => [{ "kty" => "oct", "k" => "AA" }] }],
      # Verifying an assertion needs no private parameter, so a key set that
      # publishes one is a client that has disclosed its own credential.
      ["only keys carrying private material", { "keys" => [{ "kty" => "RSA", "n" => "AA", "e" => "AQAB", "d" => "AA" }] }],
      ["an empty keys array", { "keys" => [] }],
      ["an unparseable JSON string", "{not json"],
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

      # RFC 7523 Section 3 has the server reject any assertion that does not
      # name "its own identity" as the audience. A document client_id resolves
      # to the same client, and the same keys, at every server implementing the
      # draft, so a Host header standing in for that identity would make an
      # assertion sent to one of them replayable at all the others — by
      # whoever received it. A registered client keeps the fallback (see the
      # "when the server identifies itself nowhere" context above), since its
      # uid is this server's own and would have to be registered elsewhere too.
      context "when the server identifies itself nowhere" do
        before { config_is_set(:issuer, nil) }

        it "refuses the assertion rather than accepting a Host-derived audience" do
          stub_document("jwks" => jwks)
          request = request_with(build_assertion)
          audience = request.base_url + request.path

          credentials = described_class.authenticate(
            request_with(build_assertion(claims: { "aud" => audience })),
          )

          expect(credentials).to be_nil
        end

        it "accepts the assertion once an issuer is configured" do
          config_is_set(:issuer, issuer)
          stub_document("jwks" => jwks)

          credentials = described_class.authenticate(request_with(build_assertion))

          expect(credentials).not_to be_nil
        end
      end

      # Section 4.1 permits public keys only. An inline jwks publishing
      # private material is refused with the document itself; a set fetched
      # from a jwks_uri is not part of the document, so its keys are dropped
      # instead and the assertion simply verifies against nothing.
      it "refuses a document whose inline jwks publishes private key material" do
        stub_document("jwks" => { "keys" => [JWT::JWK.new(rsa_key, { kid: kid }).export(include_private: true)] })

        expect(described_class.authenticate(request_with(build_assertion))).to be_nil
      end

      it "does not verify against private key material fetched from the document's jwks_uri" do
        jwks_uri = "https://client.example.com/jwks.json"
        stub_document("jwks_uri" => jwks_uri)
        stub_request(:get, jwks_uri).to_return(
          status: 200,
          body: { "keys" => [JWT::JWK.new(rsa_key, { kid: kid }).export(include_private: true)] }.to_json,
        )

        expect(described_class.authenticate(request_with(build_assertion))).to be_nil
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

      # A document with an empty keys array is valid, so unlike the case above
      # this one reaches the key resolver rather than failing validation.
      it "rejects the assertion when the document publishes an empty key set" do
        stub_document("jwks" => { "keys" => [] })

        expect(described_class.authenticate(request_with(build_assertion))).to be_nil
      end

      # The keys are attacker-supplied here, so the member types the jwt gem
      # trusts must fail authentication rather than reach the endpoint as a
      # 500 — and no signature is needed to get this far.
      it "rejects a document key whose member is not a string without raising" do
        stub_document("jwks" => { "keys" => [{ "kty" => "RSA", "n" => 123, "e" => "AQAB" }] })

        expect { expect(described_class.authenticate(request_with(build_assertion))).to be_nil }
          .not_to raise_error
      end

      it "rejects a document jwks_uri whose port could never be connected to" do
        stub_document("jwks_uri" => "https://client.example.com:99999999999999999999/jwks.json")

        expect { expect(described_class.authenticate(request_with(build_assertion))).to be_nil }
          .not_to raise_error
      end

      # Keys named by a document are cached apart from those of registered
      # applications, so unauthenticated traffic cannot evict the entries
      # registered clients depend on.
      it "caches document keys separately from registered application keys" do
        jwks_uri = "https://client.example.com/jwks.json"
        stub_document("jwks_uri" => jwks_uri)
        stub_request(:get, jwks_uri).to_return(status: 200, body: jwks.to_json)

        expect(described_class.authenticate(request_with(build_assertion))).not_to be_nil

        # A hit answers from the cache without running the block; a miss runs
        # it, so the sentinel tells the two apart.
        miss = "not cached"
        expect(described_class::KeyResolver.document_jwks_cache.fetch(jwks_uri) { miss }).not_to eq(miss)
        expect(described_class::KeyResolver.jwks_cache.fetch(jwks_uri) { miss }).to eq(miss)
      end

      # The separation must survive a configured private_key_jwt_jwks_cache:
      # that cache belongs to registered clients, and a document client must
      # not be able to insert entries into it or evict entries from it. The
      # double answers nothing, so any call on it fails the example.
      it "keeps document keys out of a configured custom jwks cache" do
        jwks_uri = "https://client.example.com/jwks.json"
        stub_document("jwks_uri" => jwks_uri)
        stub_request(:get, jwks_uri).to_return(status: 200, body: jwks.to_json)
        config_is_set(:private_key_jwt_jwks_cache, double("registered clients' cache"))

        expect(described_class.authenticate(request_with(build_assertion))).not_to be_nil

        miss = "not cached"
        expect(described_class::KeyResolver.document_jwks_cache.fetch(jwks_uri) { miss }).not_to eq(miss)
      end

      # Draft Section 8.2: client authentication must be "of the registered
      # type" — a document that selected "none" must not authenticate with
      # private_key_jwt just because it also publishes a JWK Set.
      it "rejects the assertion when the document selects an authentication method other than private_key_jwt" do
        stub_document("token_endpoint_auth_method" => "none", "jwks" => jwks)

        expect { expect(described_class.authenticate(request_with(build_assertion))).to be_nil }
          .not_to change(Doorkeeper::Application, :count).from(0)
      end
    end
  end
end
