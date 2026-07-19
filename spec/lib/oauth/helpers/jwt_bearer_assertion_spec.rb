# frozen_string_literal: true

require "spec_helper"
require "openssl"
require "jwt"

RSpec.describe Doorkeeper::OAuth::Helpers::JwtBearerAssertion do
  let(:rsa) { OpenSSL::PKey::RSA.generate(2048) }
  let(:ec_key) { OpenSSL::PKey::EC.generate("prime256v1") }
  let(:ec_public_key) { OpenSSL::PKey.read(ec_key.public_to_der) }
  let(:issuer) { "https://idp.example.com" }
  let(:audience) { "https://rs.example.com" }
  let(:client) { double(:client, uid: "client-1") }

  let(:config_attrs) do
    {
      jwt_bearer_trusted_issuer: ->(iss) { iss == issuer },
      jwt_bearer_issuer_key: ->(_iss, _kid) { rsa.public_key },
      jwt_bearer_allowed_algorithms: %w[RS256 ES256 PS256],
      jwt_bearer_audience: audience,
      jwt_bearer_clock_skew: 60,
      jwt_bearer_replay_store: nil,
    }
  end
  let(:config) { double(:config, **config_attrs) }

  def make_assertion(alg: "RS256", key: rsa, header: {}, payload: {})
    now = Time.now.to_i
    claims = {
      "iss" => issuer, "sub" => "user-1", "aud" => audience, "client_id" => "client-1",
      "jti" => SecureRandom.hex(8), "exp" => now + 300, "iat" => now,
    }.merge(payload)
    JWT.encode(claims, key, alg, { typ: "oauth-id-jag+jwt" }.merge(header))
  end

  def verify(assertion, config: self.config)
    described_class.verify(assertion, client: client, config: config)
  end

  def config_with(overrides)
    double(:config, **config_attrs.merge(overrides))
  end

  it "returns verified claims for a valid RS256 assertion" do
    result = verify(make_assertion)

    expect(result).to be_success
    expect(result.claims["iss"]).to eq(issuer)
    expect(result.claims["client_id"]).to eq("client-1")
  end

  it "verifies a valid ES256 assertion" do
    ec_config = config_with(jwt_bearer_issuer_key: ->(_iss, _kid) { ec_public_key })
    result = verify(make_assertion(alg: "ES256", key: ec_key), config: ec_config)

    expect(result).to be_success
  end

  it "verifies a valid PS256 assertion" do
    result = verify(make_assertion(alg: "PS256"))

    expect(result).to be_success
  end

  it "rejects a non-string assertion" do
    expect(verify(nil)).not_to be_success
    expect(verify(42)).not_to be_success
  end

  it "rejects a malformed assertion" do
    expect(verify("not-a-jwt")).not_to be_success
  end

  it "rejects typ confusion (typ: JWT)" do
    result = verify(make_assertion(header: { typ: "JWT" }))

    expect(result).not_to be_success
  end

  it "rejects alg: none" do
    header = Base64.urlsafe_encode64({ alg: "none", typ: "oauth-id-jag+jwt" }.to_json, padding: false)
    payload = Base64.urlsafe_encode64(
      { iss: issuer, sub: "user-1", aud: audience, client_id: "client-1", jti: "x", exp: Time.now.to_i + 300, iat: Time.now.to_i }.to_json,
      padding: false,
    )
    result = verify("#{header}.#{payload}.")

    expect(result).not_to be_success
  end

  it "rejects an HMAC-signed assertion" do
    result = verify(make_assertion(alg: "HS256", key: "some-shared-secret"))

    expect(result).not_to be_success
  end

  it "rejects an assertion from an untrusted issuer" do
    result = verify(make_assertion(payload: { "iss" => "https://evil.example.com" }))

    expect(result).not_to be_success
  end

  it "rejects an assertion when no key can be resolved" do
    unresolvable_config = config_with(jwt_bearer_issuer_key: ->(_iss, _kid) { nil })
    result = verify(make_assertion, config: unresolvable_config)

    expect(result).not_to be_success
  end

  it "rejects a tampered signature" do
    assertion = make_assertion
    tampered = "#{assertion[0..-2]}#{assertion[-1] == "A" ? "B" : "A"}"

    expect(verify(tampered)).not_to be_success
  end

  it "rejects an audience mismatch" do
    result = verify(make_assertion(payload: { "aud" => "https://someone-else.example.com" }))

    expect(result).not_to be_success
  end

  it "rejects an expired assertion" do
    result = verify(make_assertion(payload: { "exp" => Time.now.to_i - 1000 }))

    expect(result).not_to be_success
  end

  it "accepts an assertion just inside the clock-skew tolerance" do
    result = verify(make_assertion(payload: { "exp" => Time.now.to_i - 30 }))

    expect(result).to be_success
  end

  it "rejects an assertion issued too far in the future" do
    result = verify(make_assertion(payload: { "iat" => Time.now.to_i + 1000, "exp" => Time.now.to_i + 1300 }))

    expect(result).not_to be_success
  end

  it "rejects an assertion not yet valid per its nbf claim" do
    result = verify(make_assertion(payload: { "nbf" => Time.now.to_i + 1000 }))

    expect(result).not_to be_success
  end

  it "rejects an assertion missing a required claim" do
    result = verify(make_assertion(payload: { "jti" => nil }))

    expect(result).not_to be_success
  end

  it "rejects an assertion whose client_id claim does not match the authenticated client" do
    result = verify(make_assertion(payload: { "client_id" => "someone-else" }))

    expect(result).not_to be_success
  end

  it "rejects a replayed assertion when a replay store is configured" do
    store = Class.new do
      def initialize
        @seen = {}
      end

      def consume(jti, iss, _exp)
        key = "#{iss}:#{jti}"
        return false if @seen[key]

        @seen[key] = true
        true
      end
    end.new
    replay_config = config_with(jwt_bearer_replay_store: store)

    assertion = make_assertion
    expect(verify(assertion, config: replay_config)).to be_success
    expect(verify(assertion, config: replay_config)).not_to be_success
  end

  it "allows reuse when no replay store is configured" do
    assertion = make_assertion

    expect(verify(assertion)).to be_success
    expect(verify(assertion)).to be_success
  end

  it "accepts a PEM string from the key resolver" do
    pem_config = config_with(jwt_bearer_issuer_key: ->(_iss, _kid) { rsa.public_key.to_pem })

    expect(verify(make_assertion, config: pem_config)).to be_success
  end

  it "accepts a JWK Hash from the key resolver" do
    jwk_hash = JWT::JWK.new(rsa.public_key).export
    jwk_config = config_with(jwt_bearer_issuer_key: ->(_iss, _kid) { jwk_hash })

    expect(verify(make_assertion, config: jwk_config)).to be_success
  end

  it "tries multiple candidate keys until one verifies" do
    wrong_key = OpenSSL::PKey::RSA.generate(2048).public_key
    multi_config = config_with(jwt_bearer_issuer_key: ->(_iss, _kid) { [wrong_key, rsa.public_key] })

    expect(verify(make_assertion, config: multi_config)).to be_success
  end
end
