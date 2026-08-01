# frozen_string_literal: true

require "spec_helper"

# End-to-end probe: does a malformed (but well-signed) DPoP proof surface as a
# 400 invalid_dpop_proof, or does it escape as an unhandled 500?
describe "DPoP proof with unexpected value types", type: :request do
  let(:client) { FactoryBot.create :application }
  let(:signing_key) { OpenSSL::PKey::EC.generate("prime256v1") }
  let(:jwk) { JWT::JWK.new(signing_key).export }

  def handcrafted_proof(claims:, headers: {})
    merged = { "typ" => "dpop+jwt", "alg" => "ES256", "jwk" => jwk }.merge(headers)
    b64 = ->(h) { Base64.urlsafe_encode64(JSON.generate(h), padding: false) }
    signing_input = "#{b64.call(merged)}.#{b64.call(claims)}"
    signature = JWT::JWA.resolve("ES256").sign(data: signing_input, signing_key: signing_key)

    "#{signing_input}.#{Base64.urlsafe_encode64(signature, padding: false)}"
  end

  def authorization(username, password)
    { "HTTP_AUTHORIZATION" => ActionController::HttpAuthentication::Basic.encode_credentials(username, password) }
  end

  def post_token(proof)
    post "/oauth/token",
         params: { grant_type: "client_credentials" },
         headers: authorization(client.uid, client.secret).merge("DPoP" => proof)
  end

  it "rejects a String iat with 400, not 500" do
    post_token(handcrafted_proof(claims: { "jti" => "x", "iat" => "not-a-number" }))

    expect(response.status).to eq(400)
    expect(json_response["error"]).to eq("invalid_dpop_proof")
  end

  it "rejects an Array iat with 400, not 500" do
    post_token(handcrafted_proof(claims: { "jti" => "x", "iat" => [1, 2] }))

    expect(response.status).to eq(400)
  end

  it "rejects an unknown jwk kty with 400, not 500" do
    proof = handcrafted_proof(
      claims: { "jti" => "x", "iat" => Time.now.to_i },
      headers: { "jwk" => { "kty" => "bogus" } },
    )
    post_token(proof)

    expect(response.status).to eq(400)
  end

  it "rejects an Array jwk with 400, not 500" do
    post_token(handcrafted_proof(claims: { "jti" => "x", "iat" => Time.now.to_i },
                                 headers: { "jwk" => %w[a b] },))

    expect(response.status).to eq(400)
  end
end
