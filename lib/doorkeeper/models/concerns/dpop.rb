# frozen_string_literal: true

module Doorkeeper
  module Models
    module DPoP
      extend ActiveSupport::Concern

      module ClassMethods
        # Checks whether the token can be sender-constrained using DPoP.
        #
        # @see https://datatracker.ietf.org/doc/html/rfc9449
        #   OAuth 2.0 Demonstrating Proof of Possession (DPoP)
        def dpop_supported?
          column_names.include?("dpop_jkt")
        end

        # RFC 9449: a reused token must carry the same sender constraint the
        # request asked for. Handing a DPoP-bound token to a request with a
        # different key makes it unusable, and handing an unbound one to a
        # request that presented a proof silently drops the binding.
        #
        # @param token [Doorkeeper::AccessToken] existing token
        # @param requested_jkt [String, nil] JWK SHA-256 thumbprint
        # @return [Boolean]
        def dpop_bindings_match?(token, requested_jkt)
          return true unless dpop_supported?

          token.dpop_jkt == requested_jkt
        end
      end

      # Checks whether the token has been sender-constrained using DPoP. The token
      # is never considered sender-constrained if the DPoP migration was not run.
      #
      # @see https://datatracker.ietf.org/doc/html/rfc9449
      #   OAuth 2.0 Demonstrating Proof of Possession (DPoP)
      def uses_dpop?
        self.class.dpop_supported? && dpop_jkt.present?
      end

      # Checks whether the token is bound to the given DPoP key thumbprint (`jkt`).
      #
      # DPoP-bound (sender-constrained) access tokens are bound to a public key by its JWK
      # SHA-256 thumbprint (`dpop_jkt`). This method returns `false` if the token is not DPoP-bound,
      # otherwise it returns whether the token's stored thumbprint matches the provided `jkt`.
      #
      # @param jkt [String] The JWK SHA-256 thumbprint of the DPoP public key jkt
      # @return [Boolean] True if the token is DPoP-bound and bound to the given `jkt`
      def dpop_binding_matches?(jkt)
        return false unless uses_dpop?
        return false if jkt.blank?

        ActiveSupport::SecurityUtils.secure_compare(dpop_jkt, jkt)
      end
    end
  end
end
