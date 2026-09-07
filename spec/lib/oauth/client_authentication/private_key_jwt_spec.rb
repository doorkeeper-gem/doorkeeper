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

  before do
    config_is_set(:issuer, issuer)
    allow(Doorkeeper::Application).to receive(:by_uid).and_return(nil)
    allow(Doorkeeper::Application).to receive(:by_uid).with(client_id).and_return(application)
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

  # Stands in for a host application's own guard: it lets every assertion
  # through and records what it was handed, so the key and the expiry can be
  # read off it afterwards.
  def recording_replay_guard
    Class.new do
      attr_reader :calls

      def initialize
        @calls = []
      end

      def first_use?(key, expires_at:)
        @calls << { key: key, expires_at: expires_at }
        true
      end
    end.new
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

    # Neither identity source may take the authentication path down with it:
    # a host may not have routes yet, and Doorkeeper allows any string as the
    # issuer — including one URI.parse refuses.
    context "when an identity source cannot be read" do
      it "falls back to the other when reading Rails' default host raises" do
        allow(Rails.application).to receive(:routes).and_raise(RuntimeError)

        credentials = described_class.authenticate(
          request_with(build_assertion(claims: { "aud" => issuer })),
        )

        expect(credentials).not_to be_nil
      end

      it "still offers an issuer that is not a parseable URL" do
        config_is_set(:issuer, "https://\\")

        credentials = described_class.authenticate(
          request_with(build_assertion(claims: { "aud" => "https://\\" })),
        )

        expect(credentials).not_to be_nil
      end
    end

    # A host application commonly sets both — Rails' default_url_options for
    # its own URL helpers, and an issuer — and the two need not name the same
    # host. A client derives the token endpoint URL (OIDC Core §9) from
    # whichever it was told about, so both are offered rather than the first.
    context "when the issuer and Rails' default host name different hosts" do
      before do
        config_is_set(:issuer, "https://issuer.example.com")
        allow(Rails.application.routes)
          .to receive(:default_url_options).and_return({ protocol: "https://", host: "canonical.example.com" })
      end

      it "accepts the token endpoint URL built from the issuer" do
        credentials = described_class.authenticate(
          request_with(build_assertion(claims: { "aud" => "https://issuer.example.com/oauth/token" })),
        )

        expect(credentials).not_to be_nil
      end

      it "accepts the token endpoint URL built from Rails' default host" do
        credentials = described_class.authenticate(
          request_with(build_assertion(claims: { "aud" => "https://canonical.example.com/oauth/token" })),
        )

        expect(credentials).not_to be_nil
      end

      it "still refuses a host neither of them names" do
        credentials = described_class.authenticate(
          request_with(build_assertion(claims: { "aud" => "https://elsewhere.example.com/oauth/token" })),
        )

        expect(credentials).to be_nil
      end
    end

    # Rails' own initializers are commonly written with the scheme alone,
    # and url_for takes it either way, so the audience has to be built the
    # same from both spellings.
    context "when Rails' default_url_options names the protocol without a separator" do
      before do
        config_is_set(:issuer, nil)
        allow(Rails.application.routes)
          .to receive(:default_url_options).and_return({ protocol: "https", host: "canonical.example.com" })
      end

      it "accepts the token endpoint URL built from Rails' default host" do
        credentials = described_class.authenticate(
          request_with(build_assertion(claims: { "aud" => "https://canonical.example.com/oauth/token" })),
        )

        expect(credentials).not_to be_nil
      end
    end

    # A server reachable on a port of its own has that port in the endpoint
    # URL its clients were told about, so the audience is only this server's
    # with the port on it.
    context "when the issuer names a port" do
      before { config_is_set(:issuer, "https://as.example.com:8443") }

      it "accepts the token endpoint URL built from the issuer" do
        credentials = described_class.authenticate(
          request_with(build_assertion(claims: { "aud" => "https://as.example.com:8443/oauth/token" })),
        )

        expect(credentials).not_to be_nil
      end

      it "refuses the same URL without the port" do
        credentials = described_class.authenticate(
          request_with(build_assertion(claims: { "aud" => "https://as.example.com/oauth/token" })),
        )

        expect(credentials).to be_nil
      end
    end

    context "when Rails' default_url_options names a port" do
      before do
        config_is_set(:issuer, nil)
        allow(Rails.application.routes).to receive(:default_url_options)
          .and_return({ protocol: "https://", host: "as.example.com", port: 8443 })
      end

      it "accepts the token endpoint URL built with that port" do
        credentials = described_class.authenticate(
          request_with(build_assertion(claims: { "aud" => "https://as.example.com:8443/oauth/token" })),
        )

        expect(credentials).not_to be_nil
      end
    end

    # The other half of the identity: no issuer, but Rails knows the canonical
    # host, so the endpoint URLs built from it are audiences this server can
    # vouch for.
    context "when only Rails' default_url_options identifies the server" do
      before do
        config_is_set(:issuer, nil)
        allow(Rails.application.routes)
          .to receive(:default_url_options).and_return({ protocol: "https://", host: "as.example.com" })
      end

      it "accepts the token endpoint URL as audience" do
        credentials = described_class.authenticate(
          request_with(build_assertion(claims: { "aud" => "https://as.example.com/oauth/token" })),
        )

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

    # The built-in guard keeps URL clients' entries in a pool of their own,
    # and which pool a client is in is decided here, from provenance, and
    # carried on the key: a registered client's carries no URL-pool mark.
    it "hands the replay guard a key outside the URL pool" do
      guard = recording_replay_guard
      config_is_set(:private_key_jwt_replay_guard, guard)

      expect(described_class.authenticate(request_with(build_assertion))).not_to be_nil
      expect(guard.calls.last[:key]).to start_with("#{client_id.length}:#{client_id}:")
    end

    # The entry has to outlast the assertion, and an exp is a NumericDate: it
    # may be fractional. The guard is anchored to the truncated value because
    # that is the value the jwt gem compares against (`exp.to_i <=
    # Time.now.to_i - leeway`), so the two windows close in the same second
    # rather than leaving the assertion acceptable past the entry.
    it "anchors the entry to the exp the gem compares against" do
      guard = recording_replay_guard
      config_is_set(:private_key_jwt_replay_guard, guard)
      exp = Time.now.to_i + 60.9

      expect(described_class.authenticate(request_with(build_assertion(claims: { "exp" => exp })))).not_to be_nil
      expect(guard.calls.last[:expires_at]).to eq(exp.to_i)
    end

    # A guard keyed by a bare "client_id:jti" cannot tell those two apart, so
    # one client could burn the jti of another whose id it is a prefix of —
    # different tenants, on a host that serves several clients.
    it "keeps one client from burning the jti of a client sharing its prefix" do
      other_id = "#{client_id}:suffix"
      allow(Doorkeeper::Application).to receive(:by_uid).with(other_id).and_return(application)

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
      allow(Doorkeeper::Application).to receive(:by_uid).with(client_id).and_return(keyless)

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

    # A key serialized with nulls for the private parameters it does not
    # have publishes no private material, and the jwt gem reads it as the
    # public key it is.
    it "verifies against a key whose private members are null" do
      exported = JWT::JWK.new(rsa_key, { kid: kid }).export
      allow(application).to receive(:jwks).and_return("keys" => [exported.merge("d" => nil, "p" => nil)])

      expect(described_class.authenticate(request_with(build_assertion))).not_to be_nil
    end

    # The keys of a registered application are fetched over https only, the
    # same as a document's: a jwks_uri column left on http would otherwise
    # have this server take a client's verification keys off the wire.
    it "does not fetch a registered application's jwks_uri over http" do
      jwks_uri = "http://client.example.com/jwks.json"
      allow(application).to receive_messages(jwks: nil, jwks_uri: jwks_uri)
      request_stub = stub_request(:get, jwks_uri)

      expect(described_class.authenticate(request_with(build_assertion))).to be_nil
      expect(request_stub).not_to have_been_requested
    end

    # RFC 7517 Section 5: a JWK Set member an implementation does not
    # understand is ignored, not fatal. The jwt gem knows RSA, EC and oct
    # only, and builds every member in the Set constructor, so one key it
    # cannot build would otherwise cost the client the keys that are fine —
    # publishing an Ed25519 key beside a working RSA one would stop
    # authentication altogether.
    [
      ["an OKP key the gem cannot build",
       { "kty" => "OKP", "crv" => "Ed25519", "kid" => "ed", "x" => "11qYAYKxCrfVS_7TyWQHOg7hcvPapiMlrwIaaPcHURo" },],
      ["a key with no kty", { "kid" => "no-kty", "n" => "AA", "e" => "AQAB" }],
      ["a key with an unknown kty", { "kty" => "MADEUP", "kid" => "unknown" }],
      ["a key with a malformed base64url member", { "kty" => "RSA", "kid" => "bad", "n" => "!!!", "e" => "AQAB" }],
    ].each do |description, unusable|
      it "keeps verifying against a usable key published beside #{description}" do
        allow(application).to receive(:jwks).and_return({ "keys" => [unusable, jwk.export] })

        expect(described_class.authenticate(request_with(build_assertion))).not_to be_nil
      end
    end

    # RFC 7517 Sections 4.2 and 4.3: the publisher may say what a key is for.
    # The jwt gem's key finder matches on kid alone, so the restriction has to
    # be honoured here — a client publishing a JWE encryption key beside its
    # signing key means exactly "do not verify signatures with this one".
    [
      ["use is enc", { "use" => "enc" }],
      ["key_ops excludes verify", { "key_ops" => %w[encrypt wrapKey] }],
    ].each do |description, restriction|
      it "does not verify an assertion with a key whose #{description}" do
        allow(application).to receive(:jwks).and_return({ "keys" => [jwk.export.merge(restriction)] })

        expect(described_class.authenticate(request_with(build_assertion))).to be_nil
      end
    end

    [
      ["use is sig", { "use" => "sig" }],
      ["key_ops includes verify", { "key_ops" => %w[verify] }],
    ].each do |description, permission|
      it "verifies an assertion with a key whose #{description}" do
        allow(application).to receive(:jwks).and_return({ "keys" => [jwk.export.merge(permission)] })

        expect(described_class.authenticate(request_with(build_assertion))).not_to be_nil
      end
    end

    it "verifies against the signing key when an encryption key is published beside it" do
      encryption_key = jwk.export.merge("kid" => "enc-key", "use" => "enc")
      allow(application).to receive(:jwks).and_return({ "keys" => [encryption_key, jwk.export] })

      expect(described_class.authenticate(request_with(build_assertion))).not_to be_nil
    end

    # An unverified decode skips the gem's check that the JOSE header is an
    # object, so a header of any other JSON type is indexed into as one —
    # TypeError or NoMethodError, neither a JWT::DecodeError — from an
    # assertion no key, signature or client was needed to build.
    ["[1]", "42", "null", "true"].each do |header|
      it "rejects an assertion whose JOSE header is #{header} without raising" do
        segments = [header, { "iss" => client_id, "sub" => client_id }.to_json, "signature"]
        assertion = segments.map { |segment| Base64.urlsafe_encode64(segment, padding: false) }.join(".")

        expect { expect(described_class.authenticate(request_with(assertion))).to be_nil }
          .not_to raise_error
      end
    end

    # JSON.parse tags a payload's bytes as UTF-8 without checking them, and
    # the first regex to touch a claim carrying invalid bytes raises
    # ArgumentError (String#blank? is one): out of the unverified issuer
    # check for anyone, and out of the jti check for a signed assertion.
    it "rejects an assertion whose issuer is not valid UTF-8 without raising" do
      assertion = sign_raw_json(%({"iss":"\xff","sub":"\xff"}).b)

      expect { expect(described_class.authenticate(request_with(assertion))).to be_nil }
        .not_to raise_error
    end

    it "rejects a signed assertion whose jti is not valid UTF-8 without raising" do
      payload = %({"iss":"#{client_id}","sub":"#{client_id}","aud":"#{issuer}",) +
                %("exp":#{Time.now.to_i + 300},"jti":"a\xff"}).b

      expect { expect(described_class.authenticate(request_with(sign_raw_json(payload)))).to be_nil }
        .not_to raise_error
    end

    # A key member whose bytes are not valid UTF-8 raises ArgumentError out
    # of the base64url decoder — lazily, inside the verifying decode, when
    # the header's kid names the key, and eagerly, while the set is built,
    # when the key has no kid. A registered application's jwks is the
    # host's to fill; either way it is a failure to verify, not a 500.
    it "rejects the assertion without raising when the registered key named by kid is not valid UTF-8" do
      allow(application).to receive(:jwks).and_return({ "keys" => [jwk.export.merge("n" => "AQ\xffAB")] })

      expect { expect(described_class.authenticate(request_with(build_assertion))).to be_nil }
        .not_to raise_error
    end

    it "rejects the assertion without raising when a registered key without a kid is not valid UTF-8" do
      allow(application).to receive(:jwks).and_return({ "keys" => [jwk.export.except(:kid).merge("n" => "AQ\xffAB")] })

      expect { expect(described_class.authenticate(request_with(build_assertion(header_kid: nil)))).to be_nil }
        .not_to raise_error
    end

    # RFC 7523 Section 3 requires nbf to be honoured when present, so it is
    # pinned the way exp is: a host application that disabled it globally
    # for its own tokens does not disable it for assertions.
    context "when the host application globally disabled not-before checking" do
      around do |example|
        original = JWT.configuration.decode.verify_not_before
        JWT.configuration.decode.verify_not_before = false
        example.run
      ensure
        JWT.configuration.decode.verify_not_before = original
      end

      it "still rejects an assertion that is not yet valid" do
        credentials = described_class.authenticate(
          request_with(build_assertion(claims: { "nbf" => Time.now.to_i + 600 })),
        )

        expect(credentials).to be_nil
      end
    end

    # The gem merges the host application's global decode settings under the
    # options passed to decode, and a leeway is a common one: the assertion
    # is then accepted for that long past its exp, which is the host's call
    # — but the guard has to remember the jti for exactly as long. Remembered
    # until exp alone, the assertion was accepted again once the guard had
    # swept its entry.
    context "when the host application configured a global JWT leeway" do
      around do |example|
        original = JWT.configuration.decode.leeway
        JWT.configuration.decode.leeway = 300
        example.run
      ensure
        JWT.configuration.decode.leeway = original
      end

      it "does not accept an assertion a second time within the leeway" do
        now = Time.now.to_i
        assertion = build_assertion(claims: { "exp" => now - 10 })

        expect(described_class.authenticate(request_with(assertion))).not_to be_nil

        # Past the sweep interval, at which the guard drops entries whose
        # expiry has passed.
        allow(Time).to receive(:now).and_return(Time.at(now + described_class::ReplayGuard::SWEEP_INTERVAL + 1).utc)

        expect(described_class.authenticate(request_with(assertion))).to be_nil
      end
    end

    # The gem compares against a fractional leeway as it stands, so the
    # guard rounds one up rather than truncating it: truncated, it would
    # forget the jti during the second the gem still accepts the assertion
    # in.
    context "when the configured global JWT leeway is fractional" do
      around do |example|
        original = JWT.configuration.decode.leeway
        JWT.configuration.decode.leeway = 0.5
        example.run
      ensure
        JWT.configuration.decode.leeway = original
      end

      it "remembers the jti through the whole second the assertion is still accepted in" do
        guard = recording_replay_guard
        config_is_set(:private_key_jwt_replay_guard, guard)
        exp = Time.now.to_i + 60

        expect(described_class.authenticate(request_with(build_assertion(claims: { "exp" => exp })))).not_to be_nil
        expect(guard.calls.last[:expires_at]).to eq(exp + 1)
      end
    end

    context "with a client ID metadata document client" do
      let(:client_id) { "https://client.example.com/oauth-client" }

      before do
        config_is_set(:client_id_metadata_documents, true)
        config_is_set(:client_authentication, %i[client_secret_basic client_secret_post none private_key_jwt])
        allow(Resolv).to receive(:getaddresses).and_return(["93.184.216.34"])
        allow(Doorkeeper::Application).to receive(:by_uid).and_call_original
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

        # No assertion can be accepted in this configuration, so answering an
        # unauthenticated request with an outbound fetch of an
        # attacker-chosen URL — and possibly a second one for its jwks_uri —
        # is work done to say no.
        it "fetches nothing on the way to refusing" do
          request_stub = stub_document("jwks" => jwks)

          expect(described_class.authenticate(request_with(build_assertion))).to be_nil
          expect(request_stub).not_to have_been_requested
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

      it "refuses a document naming an http jwks_uri" do
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

      it "hands the replay guard a key in the URL pool" do
        stub_document("jwks" => jwks)
        guard = recording_replay_guard
        config_is_set(:private_key_jwt_replay_guard, guard)

        expect(described_class.authenticate(request_with(build_assertion))).not_to be_nil
        expect(guard.calls.last[:key]).to start_with(described_class::ReplayGuard::URL_POOL_PREFIX)
      end

      # RFC 8259 Section 8.1: a document (or jwks_uri body) that is not valid
      # UTF-8 is refused by the fetcher, before its bytes can reach a regex or
      # the base64url decoder a key member goes through.
      it "rejects the assertion without raising when the document's inline key is not valid UTF-8" do
        body = %({"client_id":"#{client_id}","token_endpoint_auth_method":"private_key_jwt",) +
               %("jwks":{"keys":[{"kty":"RSA","kid":"#{kid}","n":"AQ\xffAB","e":"AQAB"}]}}).b
        stub_request(:get, client_id).to_return(status: 200, body: body)

        expect { expect(described_class.authenticate(request_with(build_assertion))).to be_nil }
          .not_to raise_error
      end

      # The other way this server may identify itself for a document client's
      # audience: Rails' default_url_options host, from which the token
      # endpoint URL is built. The Host header stays out of it either way.
      context "when the server identifies itself through Rails' default_url_options host" do
        around do |example|
          original = Rails.application.routes.default_url_options
          Rails.application.routes.default_url_options = { host: "as.example.com" }
          example.run
        ensure
          Rails.application.routes.default_url_options = original
        end

        before { config_is_set(:issuer, nil) }

        it "accepts the token endpoint URL built from that host as audience" do
          stub_document("jwks" => jwks)
          assertion = build_assertion(claims: { "aud" => "https://as.example.com/oauth/token" })

          expect(described_class.authenticate(request_with(assertion))).not_to be_nil
        end

        it "still refuses a Host-derived audience" do
          stub_document("jwks" => jwks)
          request = request_with(build_assertion)
          audience = request.base_url + request.path

          expect(described_class.authenticate(request_with(build_assertion(claims: { "aud" => audience })))).to be_nil
        end
      end

      # Draft Section 7.2 permits pre-registering a Client Identifier URL, and
      # Section 7.1 says the https:// prefix alone cannot tell such a
      # registration from a document client — the application table can. A
      # registered application holding the URL is verified against the keys
      # registered for it, and its URL is never fetched: verified against
      # whatever the URL serves instead, whoever controls it could sign as
      # the registered client with keys of their own.
      context "when a registered application holds the URL" do
        let(:document_key) { OpenSSL::PKey::RSA.generate(2048) }

        before do
          FactoryBot.create(:application, uid: client_id, jwks: jwks.to_json)
          stub_document("jwks" => { "keys" => [JWT::JWK.new(document_key.public_key, { kid: kid }).export] })
        end

        it "verifies against the registered keys without fetching the document" do
          expect(described_class.authenticate(request_with(build_assertion))).not_to be_nil
          expect(a_request(:get, client_id)).not_to have_been_made
        end

        it "does not verify against the keys the URL serves" do
          expect(described_class.authenticate(request_with(build_assertion(key: document_key)))).to be_nil
          expect(a_request(:get, client_id)).not_to have_been_made
        end

        # A registered client's uid is this server's own, so the request-URL
        # audience fallback stays available to it — see the "when the server
        # identifies itself nowhere" contexts above for both sides.
        it "keeps the request-URL audience fallback of a registered client" do
          config_is_set(:issuer, nil)
          request = request_with(build_assertion)
          audience = request.base_url + request.path

          credentials = described_class.authenticate(request_with(build_assertion(claims: { "aud" => audience })))

          expect(credentials).not_to be_nil
        end

        it "hands the replay guard a key outside the URL pool" do
          guard = recording_replay_guard
          config_is_set(:private_key_jwt_replay_guard, guard)

          expect(described_class.authenticate(request_with(build_assertion))).not_to be_nil
          expect(guard.calls.last[:key]).to start_with("#{client_id.length}:#{client_id}:")
        end

        # A stamped row outliving the feature is no registered client, so its
        # assertion is refused before any key is resolved and no jti is spent.
        it "refuses a stamped row once the feature is disabled" do
          Doorkeeper::Application.find_by(uid: client_id).update!(client_id_metadata_materialized_at: Time.now.utc)
          config_is_set(:client_id_metadata_documents, false)

          expect(described_class.authenticate(request_with(build_assertion))).to be_nil
          expect(a_request(:get, client_id)).not_to have_been_made
        end

        # The stamp, not the uid, is what makes a row the feature's: once the
        # row carries one, the document is the client's source of keys again.
        it "verifies a stamped row against its document" do
          Doorkeeper::Application.find_by(uid: client_id).update!(client_id_metadata_materialized_at: Time.now.utc)

          expect(described_class.authenticate(request_with(build_assertion(key: document_key)))).not_to be_nil
          expect(described_class.authenticate(request_with(build_assertion))).to be_nil
        end
      end
    end
  end
end
