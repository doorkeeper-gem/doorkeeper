# frozen_string_literal: true

module Doorkeeper
  module OAuth
    class DPoPProof
      begin
        require "jwt"
      rescue LoadError
        raise %(The `jwt` gem is required for DPoP support. Add `gem "jwt"` to your Gemfile.)
      end

      include Validations

      validate :presence,          error: :blank
      validate :single_proof,      error: :multiple_dpop_proofs
      validate :type,              error: :invalid_type
      validate :signing_algorithm, error: :invalid_signing_algorithm
      validate :jwk,               error: :invalid_jwk
      validate :jti,               error: :invalid_jti
      validate :iat,               error: :invalid_iat
      validate :ath,               error: :invalid_ath
      validate :htm,               error: :invalid_htm
      validate :htu,               error: :invalid_htu
      validate :signature,         error: :invalid_signature

      delegate :blank?, to: :dpop

      def initialize(request, access_token = nil)
        @request = request
        @access_token = access_token

        @dpop = request.headers["DPoP"]
      end

      def validate
        super.tap { @valid = @error.nil? }
      end

      def valid?
        return @valid if defined?(@valid)

        super
      end

      def jkt
        return nil unless valid?

        @jkt ||= JWT::JWK::Thumbprint.new(jwk).generate
      end

      private

      attr_reader :access_token, :dpop, :request

      def claims
        return @claims if defined?(@claims)

        decode_without_verifying_signature
        @claims
      end

      def headers
        return @headers if defined?(@headers)

        decode_without_verifying_signature
        @headers
      end

      def decode_without_verifying_signature
        @claims, @headers = JWT.decode(dpop, nil, false)
      rescue JWT::DecodeError
        @claims = {}
        @headers = {}
      end

      def jwk
        @jwk ||= headers["jwk"] && JWT::JWK.import(headers["jwk"])
      end

      def validate_presence
        present?
      end

      def validate_single_proof
        dpop.split(",").size == 1 && dpop.split(";").size == 1
      end

      def validate_type
        headers["typ"] == "dpop+jwt"
      end

      def validate_signing_algorithm
        Doorkeeper.config.dpop_signature_algorithms.include?(headers["alg"])
      end

      def validate_jwk
        jwk && !jwk.private?
      end

      def validate_jti
        claims["jti"].present?
      end

      def validate_iat
        claims["iat"].present? &&
          (claims["iat"] - Time.now.to_i).abs <= Doorkeeper.config.dpop_iat_leeway
      end

      def validate_ath
        return true unless access_token

        claims["ath"] == Base64.urlsafe_encode64(Digest::SHA256.digest(access_token), padding: false)
      end

      def validate_htm
        claims["htm"] == request.request_method
      end

      def validate_htu
        claims["htu"] == (request.base_url + request.path)
      end

      def validate_signature
        JWT.decode(dpop, jwk.keypair, true, algorithms: [headers["alg"]])
      rescue JWT::DecodeError, JWT::JWKError
        false
      end
    end
  end
end
