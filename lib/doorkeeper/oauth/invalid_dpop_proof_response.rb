# frozen_string_literal: true

module Doorkeeper
  module OAuth
    class InvalidDPoPProofResponse < ErrorResponse
      def initialize(attributes = {})
        super(attributes.merge(name: :invalid_dpop_proof, state: :unauthorized))
      end

      def status
        :unauthorized
      end

      def description
        @description ||= I18n.translate(:invalid_dpop_proof, scope: %i[doorkeeper errors messages])
      end

      protected

      def exception_class
        Doorkeeper::Errors::InvalidDPoPProof
      end
    end
  end
end
