# frozen_string_literal: true

require "spec_helper"

# Probe: what happens when a DPoP proof carries well-formed JWT structure but
# unexpected *types* in the header/claim values?
RSpec.describe Doorkeeper::OAuth::DPoPProof do
  let(:signing_key) { OpenSSL::PKey::EC.generate("prime256v1") }
  let(:jwk) { JWT::JWK.new(signing_key).export }

  def proof_for(claims:, headers: {})
    base_headers = { "typ" => "dpop+jwt", "alg" => "ES256", "jwk" => jwk }
    merged = base_headers.merge(headers)
    JWT.encode(claims, signing_key, merged["alg"], merged)
  end

  # JWT.encode refuses to emit a non-Numeric `iat`, but nothing stops an
  # attacker from assembling the compact serialization by hand. Also, a JWT
  # segment only has to be valid JSON, so `claims` and `headers` may be an
  # Array or scalar rather than the expected Hash.
  def handcrafted_proof(claims:, headers: {})
    base = { "typ" => "dpop+jwt", "alg" => "ES256", "jwk" => jwk }
    header = headers.is_a?(Hash) ? base.merge(headers) : headers
    b64 = ->(h) { Base64.urlsafe_encode64(JSON.generate(h), padding: false) }
    signing_input = "#{b64.call(header)}.#{b64.call(claims)}"
    signature = JWT::JWA.resolve("ES256").sign(data: signing_input, signing_key: signing_key)

    "#{signing_input}.#{Base64.urlsafe_encode64(signature, padding: false)}"
  end

  def request_double(token)
    instance_double(
      ActionDispatch::Request,
      headers: { "DPoP" => token },
      request_method: "POST",
      base_url: "https://example.com",
      path: "/oauth/token",
    )
  end

  def validate!(token)
    described_class.new(request_double(token)).valid?
  end

  describe "non-integer iat" do
    it "returns false rather than raising for a String iat" do
      token = handcrafted_proof(claims: { "jti" => "x", "iat" => "not-a-number" })

      expect { validate!(token) }.not_to raise_error
      expect(validate!(token)).to be false
    end

    it "returns false rather than raising for an Array iat" do
      token = handcrafted_proof(claims: { "jti" => "x", "iat" => [1, 2] })

      expect { validate!(token) }.not_to raise_error
    end

    it "returns false rather than raising for a Hash iat" do
      token = handcrafted_proof(claims: { "jti" => "x", "iat" => { "a" => 1 } })

      expect { validate!(token) }.not_to raise_error
    end
  end

  describe "malformed jwk header" do
    it "returns false rather than raising for a String jwk" do
      token = proof_for(claims: { "jti" => "x", "iat" => Time.now.to_i },
                        headers: { "jwk" => "i-am-not-a-jwk" },)

      expect { validate!(token) }.not_to raise_error
    end

    it "returns false rather than raising for an Array jwk" do
      token = proof_for(claims: { "jti" => "x", "iat" => Time.now.to_i },
                        headers: { "jwk" => %w[a b] },)

      expect { validate!(token) }.not_to raise_error
    end

    it "returns false rather than raising for a jwk with an unknown kty" do
      token = proof_for(claims: { "jti" => "x", "iat" => Time.now.to_i },
                        headers: { "jwk" => { "kty" => "bogus" } },)

      expect { validate!(token) }.not_to raise_error
    end
  end

  describe "non-Hash jwt segments" do
    it "returns false rather than raising for an Array payload" do
      token = handcrafted_proof(claims: [1, 2, 3])

      expect(validate!(token)).to be false
    end

    it "returns false rather than raising for a numeric payload" do
      token = handcrafted_proof(claims: 42)

      expect(validate!(token)).to be false
    end

    it "returns false rather than raising for an Array header" do
      token = handcrafted_proof(claims: { "jti" => "x", "iat" => Time.now.to_i }, headers: [1, 2])

      expect(validate!(token)).to be false
    end

    it "returns false rather than raising for a numeric header" do
      token = handcrafted_proof(claims: { "jti" => "x", "iat" => Time.now.to_i }, headers: 42)

      expect(validate!(token)).to be false
    end
  end

  describe "baseline: a well-formed proof still validates" do
    it "is valid" do
      token = proof_for(claims: {
                          "jti" => "x",
                          "iat" => Time.now.to_i,
                          "htm" => "POST",
                          "htu" => "https://example.com/oauth/token",
                        })

      expect(validate!(token)).to be true
    end
  end
end
