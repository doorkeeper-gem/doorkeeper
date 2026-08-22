# frozen_string_literal: true

require "spec_helper"

RSpec.describe Doorkeeper::OAuth::DPoPProof do
  subject(:dpop_proof) { described_class.new(request, access_token) }

  let(:dpop_signature_algorithms) { ["ES256"] }

  let(:request) do
    instance_double(ActionDispatch::Request, env:, request_method:, url:)
  end
  let(:env) { { "HTTP_DPOP" => dpop_header } }
  let(:request_method) { "GET" }
  let(:url) { "https://protected.example.net/resource" }

  let(:access_token) { nil }

  let(:dpop_header) { JWT.encode(claims, signing_key, alg, jwt_headers) }

  let(:claims) { { "jti" => "jti_01", "iat" => iat, "htm" => htm, "htu" => htu } }
  let(:htm) { request_method }
  let(:htu) { url }
  let(:iat) { Time.current.to_i }

  let(:jwt_headers) { { "typ" => typ, "alg" => alg, "jwk" => jwk } }
  let(:alg) { "ES256" }
  let(:jwk) { JWT::JWK.new(signing_key).export }
  let(:signing_key) { OpenSSL::PKey::EC.generate("prime256v1") }
  let(:typ) { "dpop+jwt" }

  before do
    allow(Doorkeeper).to receive(:config).and_return(
      instance_double(Doorkeeper::Config, dpop_iat_leeway: 300, dpop_signature_algorithms:),
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
      context "when the proof alg is not among the configured algorithms" do
        let(:alg) { "RS256" }
        let(:signing_key) { OpenSSL::PKey::RSA.generate(2048) }

        include_examples "invalid because", :invalid_signing_algorithm
      end

      context "when the configuration allows a disallowed algorithm" do
        let(:alg) { "none" }
        let(:dpop_header) { JWT.encode(claims, nil, "none", jwt_headers) }
        let(:dpop_signature_algorithms) { %w[none] }

        include_examples "invalid because", :invalid_signing_algorithm
      end
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
        let(:htu) { "#{url}/other" }

        include_examples "invalid because", :invalid_htu
      end

      context "when htu matches the request URI but on a different port" do
        let(:url) { "https://protected.example.net:8443/resource" }
        let(:htu) { "https://protected.example.net:443/resource" }

        include_examples "invalid because", :invalid_htu
      end

      context "when htu is not a string" do
        let(:claims) { super().merge("htu" => { "not" => "a string" }) }

        include_examples "invalid because", :invalid_htu
      end

      context "when htu is not a parseable URI" do
        let(:htu) { "http://[invalid" }

        include_examples "invalid because", :invalid_htu
      end

      context "when htu includes a query string" do
        let(:htu) { "#{url}?foo=bar" }

        it "is valid" do
          dpop_proof.validate
          expect(dpop_proof).to be_valid
          expect(dpop_proof.error).to be_nil
        end
      end

      context "when htu includes a fragment" do
        let(:htu) { "#{url}#section" }

        it "is valid" do
          dpop_proof.validate
          expect(dpop_proof).to be_valid
          expect(dpop_proof.error).to be_nil
        end
      end

      context "when htu includes the default port" do
        let(:url) { "https://protected.example.net/resource" }
        let(:htu) { "https://protected.example.net:443/resource" }

        it "is valid" do
          dpop_proof.validate
          expect(dpop_proof).to be_valid
          expect(dpop_proof.error).to be_nil
        end
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

  # doorkeeper-jwt defines Doorkeeper::JWT, which shadows the jwt gem for any
  # bare JWT reference made inside the Doorkeeper module — every gem reference
  # in DPoPProof must be written ::JWT to survive that.
  context "when doorkeeper-jwt's Doorkeeper::JWT module is defined" do
    before do
      stub_const("Doorkeeper::JWT", Module.new)
    end

    it "still validates a valid proof and computes its thumbprint" do
      dpop_proof.validate

      expect(dpop_proof).to be_valid
      expected_jwk = JWT::JWK.import(jwt_headers.fetch("jwk"))
      expect(dpop_proof.jkt).to eq(JWT::JWK::Thumbprint.new(expected_jwk).generate)
    end

    context "with a malformed proof value" do
      let(:dpop_header) { "not-jwt" }

      include_examples "invalid because", :invalid_type
    end
  end
end
