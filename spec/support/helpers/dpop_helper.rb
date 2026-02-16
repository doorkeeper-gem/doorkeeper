# frozen_string_literal: true

require "jwt"

module DPoPHelper
  def build_dpop_proof(htm:, htu:, signing_key: OpenSSL::PKey::EC.generate("prime256v1"))
    claims = { "jti" => "jti_01", "iat" => Time.current.to_i, "htm" => htm, "htu" => htu }

    headers = { "typ" => "dpop+jwt", "alg" => "ES256", "jwk" => JWT::JWK.new(signing_key).export }

    JWT.encode(claims, signing_key, headers["alg"], headers)
  end

  def dpop_proof_double(messages = {})
    blank = messages.fetch(:blank?, false)
    valid = messages.fetch(:valid?, !blank)

    raise ArgumentError, "can't be blank? && valid?" if blank && valid

    instance_double(Doorkeeper::OAuth::DPoPProof, blank?: blank)
      .tap { |it| allow(it).to receive(:valid?) { it.present? && valid } }
      .tap { |it| allow(it).to receive(:jkt) { !it.valid? ? nil : "jkt_123" } }
  end
end

RSpec.configuration.send :include, DPoPHelper
