# frozen_string_literal: true

require "spec_helper"

RSpec.describe Doorkeeper::OAuth::DPoPProof do
  subject(:dpop_proof) { described_class.new(request, access_token) }

  let(:request) do
    instance_double(ActionDispatch::Request, base_url:, headers: request_headers, path:, request_method:)
  end
  let(:base_url) { "https://protected.example.net" }
  let(:path) { "/resource" }
  let(:request_headers) { ActionDispatch::Http::Headers.from_hash("HTTP_DPOP" => dpop_header) }
  let(:request_method) { "GET" }

  let(:access_token) { nil }

  let(:dpop_header) { JWT.encode(claims, signing_key, alg, jwt_headers) }

  let(:claims) { { "jti" => "jti_01", "iat" => iat, "htm" => htm, "htu" => htu } }
  let(:htm) { request_method }
  let(:htu) { base_url + path }
  let(:iat) { Time.current.to_i }

  let(:jwt_headers) { { "typ" => typ, "alg" => alg, "jwk" => jwk } }
  let(:alg) { "ES256" }
  let(:jwk) { JWT::JWK.new(signing_key).export }
  let(:signing_key) { OpenSSL::PKey::EC.generate("prime256v1") }
  let(:typ) { "dpop+jwt" }

  before do
    allow(Doorkeeper).to receive(:config).and_return(
      instance_double(Doorkeeper::Config, dpop_iat_leeway: 300, dpop_signature_algorithms: ["ES256"]),
    )

    Timecop.freeze(Time.current)
  end

  after { Timecop.return }

  shared_examples "invalid because" do |expected_error|
    it "is invalid and has error #{expected_error}" do
      dpop_proof.validate

      expect(dpop_proof).not_to be_valid
      expect(dpop_proof.error).to eq(expected_error)
    end
  end

  describe "#validate" do
    it "is valid and has no error" do
      dpop_proof.validate
      expect(dpop_proof).to be_valid
      expect(dpop_proof.error).to be_nil
    end

    context "when dpop header is missing" do
      let(:dpop_header) { nil }

      include_examples "invalid because", :blank
    end

    context "when dpop header is blank" do
      let(:dpop_header) { "" }

      include_examples "invalid because", :blank
    end

    context "when dpop header is not a jwt" do
      let(:dpop_header) { "not-jwt" }

      include_examples "invalid because", :invalid_type
    end

    describe "single_proof" do
      context "when multiple proofs separated by comma" do
        let(:dpop_header) { "a.b.c,d.e.f" }

        include_examples "invalid because", :multiple_dpop_proofs
      end

      context "when multiple proofs separated by semicolon" do
        let(:dpop_header) { "a.b.c;d.e.f" }

        include_examples "invalid because", :multiple_dpop_proofs
      end
    end

    describe "type" do
      let(:typ) { "not-dpop" }

      include_examples "invalid because", :invalid_type
    end

    describe "alg" do
      let(:alg) { "RS256" }
      let(:signing_key) { OpenSSL::PKey::RSA.generate(2048) }

      include_examples "invalid because", :invalid_signing_algorithm
    end

    describe "jwk" do
      context "when jwk is missing" do
        let(:jwt_headers) { super().except("jwk") }

        include_examples "invalid because", :invalid_jwk
      end

      context "when jwk is not a hash" do
        let(:jwk) { "not-a-jwk" }

        include_examples "invalid because", :invalid_jwk
      end

      context "when jwk includes private material" do
        let(:jwk) { JWT::JWK.new(signing_key).export(include_private: true) }

        include_examples "invalid because", :invalid_jwk
      end
    end

    describe "jti" do
      let(:claims) { super().except("jti") }

      include_examples "invalid because", :invalid_jti
    end

    describe "iat" do
      context "when iat is missing" do
        let(:claims) { super().except("iat") }

        include_examples "invalid because", :invalid_iat
      end

      context "when iat outside leeway in the future" do
        let(:claims) { super().merge("iat" => iat + Doorkeeper.config.dpop_iat_leeway + 1) }

        include_examples "invalid because", :invalid_iat
      end

      context "when iat outside leeway in the past" do
        let(:claims) { super().merge("iat" => iat - Doorkeeper.config.dpop_iat_leeway - 1) }

        include_examples "invalid because", :invalid_iat
      end
    end

    describe "ath" do
      let(:access_token) { "access_token_01" }

      context "when ath is missing" do
        include_examples "invalid because", :invalid_ath
      end

      context "when ath mismatches access_token" do
        let(:claims) { super().merge("ath" => "wrong") }

        include_examples "invalid because", :invalid_ath
      end

      context "when ath matches access_token" do
        let(:claims) do
          digest = Digest::SHA256.digest(access_token)
          super().merge("ath" => Base64.urlsafe_encode64(digest, padding: false))
        end

        it "is valid" do
          dpop_proof.validate
          expect(dpop_proof).to be_valid
          expect(dpop_proof.error).to be_nil
        end
      end
    end

    describe "htm" do
      let(:htm) { "POST" }

      include_examples "invalid because", :invalid_htm
    end

    describe "htu" do
      context "when htu does not match request URI" do
        let(:htu) { "#{base_url}/other" }

        include_examples "invalid because", :invalid_htu
      end

      context "when htu includes query string" do
        let(:htu) { "#{base_url}#{path}?foo=bar" }

        include_examples "invalid because", :invalid_htu
      end
    end

    describe "signature" do
      context "when jwt was signed with different private key pair to the jwk in the header" do
        let(:dpop_header) do
          JWT.encode(claims, OpenSSL::PKey::EC.generate("prime256v1"), alg, jwt_headers)
        end

        include_examples "invalid because", :invalid_signature
      end
    end
  end

  describe "#jkt" do
    context "when the proof is valid" do
      it "returns the thumbprint for the public jwk in the header" do
        expected_jwk = JWT::JWK.import(jwt_headers.fetch("jwk"))
        expected_jkt = JWT::JWK::Thumbprint.new(expected_jwk).generate

        expect(dpop_proof.jkt).to eq(expected_jkt)
      end
    end

    context "when the proof is invalid" do
      let(:dpop_header) { "not-jwt" }

      it "returns nil" do
        expect(dpop_proof.jkt).to be_nil
      end
    end
  end
end
