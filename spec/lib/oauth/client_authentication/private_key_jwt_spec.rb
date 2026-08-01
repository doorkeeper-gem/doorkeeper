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

    it "accepts the called endpoint's URL as audience" do
      request = request_with(build_assertion)

      credentials = described_class.authenticate(
        request_with(build_assertion(claims: { "aud" => "#{issuer}#{request.path}" })),
      )

      expect(credentials).not_to be_nil
    end

    # Only the endpoint that was actually called is an audience, not any URL
    # under the server's base URL.
    it "rejects the URL of another endpoint on the server as audience" do
      credentials = described_class.authenticate(
        request_with(build_assertion(claims: { "aud" => "#{issuer}/other" })),
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

      # Falling back to the request would let whoever sends the assertion
      # choose the audience it is checked against, so an assertion minted for
      # another authorization server could be replayed here behind a forwarded
      # Host header. With no identity of its own the server accepts no
      # audience at all instead.
      it "refuses the assertion rather than falling back to the request URL" do
        request = request_with(build_assertion)
        audience = request.base_url + request.path

        credentials = described_class.authenticate(request_with(build_assertion(claims: { "aud" => audience })))

        expect(credentials).to be_nil
      end

      it "refuses an assertion carrying the request's token endpoint URL" do
        credentials = described_class.authenticate(
          request_with(build_assertion(claims: { "aud" => "http://example.org/oauth/token" })),
        )

        expect(credentials).to be_nil
      end

      # No assertion can authenticate against an empty audience list, so the
      # client's keys are never resolved — for a client published through a
      # jwks_uri that would be an outbound request on every cache miss.
      it "refuses without resolving the client's keys" do
        expect(described_class::KeyResolver).not_to receive(:jwk_set_for)

        expect(described_class.authenticate(request_with(build_assertion))).to be_nil
      end
    end

    context "when only Rails' default_url_options identifies the server" do
      before do
        config_is_set(:issuer, nil)
        allow(::Rails.application.routes).to receive(:default_url_options)
          .and_return(protocol: "https", host: "as.example.com")
      end

      it "accepts an endpoint URL built from it" do
        request = request_with(build_assertion)

        credentials = described_class.authenticate(
          request_with(build_assertion(claims: { "aud" => "https://as.example.com#{request.path}" })),
        )

        expect(credentials).not_to be_nil
      end

      it "rejects an audience built from the request's Host header" do
        request = request_with(build_assertion)
        audience = request.base_url + request.path

        credentials = described_class.authenticate(request_with(build_assertion(claims: { "aud" => audience })))

        expect(credentials).to be_nil
      end
    end

    # The audience check must not depend on there being a fully booted Rails
    # application: the issuer alone still identifies the server.
    context "when no Rails application answers default_url_options" do
      it "still derives the endpoint URLs from the issuer without an application" do
        request = request_with(build_assertion)
        allow(::Rails).to receive(:application).and_return(nil)

        credentials = described_class.authenticate(
          request_with(build_assertion(claims: { "aud" => "#{issuer}#{request.path}" })),
        )

        expect(credentials).not_to be_nil
      end

      it "still derives the endpoint URLs from the issuer without routes" do
        request = request_with(build_assertion)
        allow(::Rails.application).to receive(:routes).and_return(nil)

        credentials = described_class.authenticate(
          request_with(build_assertion(claims: { "aud" => "#{issuer}#{request.path}" })),
        )

        expect(credentials).not_to be_nil
      end
    end

    # A non-default port is part of the server's identity, so it has to show up
    # in the endpoint URLs an audience is checked against.
    context "when the issuer carries a non-default port" do
      before { config_is_set(:issuer, "https://as.example.com:8443") }

      it "accepts the called endpoint's URL as audience" do
        request = request_with(build_assertion)

        credentials = described_class.authenticate(
          request_with(build_assertion(claims: { "aud" => "https://as.example.com:8443#{request.path}" })),
        )

        expect(credentials).not_to be_nil
      end

      it "rejects the same URL without the port" do
        request = request_with(build_assertion)

        credentials = described_class.authenticate(
          request_with(build_assertion(claims: { "aud" => "https://as.example.com#{request.path}" })),
        )

        expect(credentials).to be_nil
      end
    end

    # The token endpoint URL is built the way MetadataResponse advertises it, so
    # a host application that mounted Doorkeeper without the token routes simply
    # contributes no such audience.
    it "accepts the called endpoint's URL when the token route is not mounted" do
      allow(Doorkeeper::Rails::Routes).to receive(:mapping).and_return({})
      request = request_with(build_assertion)

      credentials = described_class.authenticate(
        request_with(build_assertion(claims: { "aud" => "#{issuer}#{request.path}" })),
      )

      expect(credentials).not_to be_nil
    end

    # Doorkeeper allows any string as the issuer, so one that is not an
    # absolute URL identifies the server for the audience check even though no
    # endpoint URL can be derived from it.
    context "when the issuer is not a URL" do
      before { config_is_set(:issuer, "urn:example:as") }

      it "accepts the issuer itself as audience" do
        credentials = described_class.authenticate(
          request_with(build_assertion(claims: { "aud" => "urn:example:as" })),
        )

        expect(credentials).not_to be_nil
      end

      it "rejects an audience built from the request's Host header" do
        request = request_with(build_assertion)
        audience = request.base_url + request.path

        credentials = described_class.authenticate(request_with(build_assertion(claims: { "aud" => audience })))

        expect(credentials).to be_nil
      end
    end

    # An issuer string URI cannot parse is still the server's declared identity:
    # it is accepted as an audience literally, and no endpoint URL is derived
    # from it rather than the parse failure bubbling out of authentication.
    context "when the issuer is not a parseable URI" do
      before { config_is_set(:issuer, "http://[as.example.com") }

      it "accepts the issuer itself as audience" do
        credentials = described_class.authenticate(
          request_with(build_assertion(claims: { "aud" => "http://[as.example.com" })),
        )

        expect(credentials).not_to be_nil
      end

      it "rejects an audience built from the request's Host header" do
        request = request_with(build_assertion)
        audience = request.base_url + request.path

        credentials = described_class.authenticate(request_with(build_assertion(claims: { "aud" => audience })))

        expect(credentials).to be_nil
      end
    end

    # The token endpoint URL is generated through the routes the host
    # application mounted; when that fails (the tokens controller is skipped
    # or mapped to something no route reaches) the other audiences still stand
    # rather than the failure bubbling out of authentication.
    context "when the token endpoint URL cannot be generated" do
      before do
        allow(Doorkeeper::Rails::Routes).to receive(:mapping)
          .and_return(tokens: { controllers: "doorkeeper/unmounted_tokens" })
      end

      it "still accepts the called endpoint's URL as audience" do
        request = request_with(build_assertion)

        credentials = described_class.authenticate(
          request_with(build_assertion(claims: { "aud" => "#{issuer}#{request.path}" })),
        )

        expect(credentials).not_to be_nil
      end

      it "no longer accepts the token endpoint URL as audience" do
        credentials = described_class.authenticate(
          request_with(build_assertion(claims: { "aud" => "#{issuer}/oauth/token" })),
        )

        expect(credentials).to be_nil
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

    # RFC 7523 §3: the jti is a string identifier. A blank one would make every
    # assertion share the same replay key, so it is refused like a missing one.
    it "rejects an assertion whose jti is blank" do
      credentials = described_class.authenticate(request_with(build_assertion(claims: { "jti" => "" })))

      expect(credentials).to be_nil
    end

    it "rejects an assertion whose jti is not a string" do
      credentials = described_class.authenticate(request_with(build_assertion(claims: { "jti" => 42 })))

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
        .with(a_string_starting_with("#{client_id}:"), expires_at: kind_of(Integer))
        .twice
        .and_return(true, false)
      config_is_set(:private_key_jwt_replay_guard, guard)

      assertion = build_assertion

      expect(described_class.authenticate(request_with(assertion))).not_to be_nil
      expect(described_class.authenticate(request_with(assertion))).to be_nil
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

    # A JWK Set is client-controlled and carries the keys a client is
    # authenticated with, so it is only ever fetched over TLS: an http://
    # jwks_uri is refused without any outbound request at all.
    it "refuses to fetch a jwks_uri that is not https" do
      jwks_uri = "http://client.example.com/jwks.json"
      allow(application).to receive_messages(jwks: nil, jwks_uri: jwks_uri)

      expect(described_class.authenticate(request_with(build_assertion))).to be_nil
      expect(a_request(:get, jwks_uri)).not_to have_been_made
    end

    # Only JSON objects are stored, so a jwks_uri answering with any other
    # JSON value fails authentication and is not cached.
    it "rejects the assertion when the jwks_uri does not answer with a JSON object" do
      jwks_uri = "https://client.example.com/jwks.json"
      allow(application).to receive_messages(jwks: nil, jwks_uri: jwks_uri)
      fetcher = instance_double(Doorkeeper::HttpFetcher, fetch: "[1, 2]")
      allow(Doorkeeper::HttpFetcher).to receive(:new).and_return(fetcher)

      expect(described_class.authenticate(request_with(build_assertion))).to be_nil
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

    # A jwks attribute that is a string but not valid JSON must fail
    # authentication rather than raise a JSON::ParserError out of the token
    # endpoint.
    it "returns nil when the application's jwks is a malformed JSON string" do
      allow(application).to receive(:jwks).and_return("{ not json")

      expect { expect(described_class.authenticate(request_with(build_assertion))).to be_nil }
        .not_to raise_error
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
  end
end
