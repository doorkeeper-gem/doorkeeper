# frozen_string_literal: true

module Doorkeeper
  module Rails
    module Helpers
      def doorkeeper_authorize!(*scopes, dpop: nil)
        unless dpop.nil? || dpop == :required
          raise ArgumentError, "dpop must be `:required` or `nil`, got: `#{dpop.inspect}`"
        end

        @_doorkeeper_scopes = scopes.presence || Doorkeeper.config.default_scopes
        @_doorkeeper_dpop = if Doorkeeper.config.access_token_methods == %i[from_dpop_authorization]
                              :required
                            else
                              dpop
                            end

        doorkeeper_render_error unless valid_doorkeeper_token?
      end

      def doorkeeper_unauthorized_render_options(**); end

      def doorkeeper_forbidden_render_options(**); end

      def valid_doorkeeper_token?
        doorkeeper_token&.acceptable?(@_doorkeeper_scopes) &&
          satisified_doorkeeper_token_dpop_binding?
      end

      def satisified_doorkeeper_token_dpop_binding?
        if @_doorkeeper_dpop == :required || @_doorkeeper_access_token_method == :from_dpop_authorization
          doorkeeper_dpop_proof.valid? && doorkeeper_token.dpop_binding_matches?(doorkeeper_dpop_proof.jkt)
        elsif Doorkeeper.config.access_token_model.dpop_supported?
          if doorkeeper_token.uses_dpop?
            return false unless @_doorkeeper_access_token_method == :from_dpop_authorization # downgrade attempt

            doorkeeper_dpop_proof.valid? && doorkeeper_token.dpop_binding_matches?(doorkeeper_dpop_proof.jkt)
          else
            true
          end
        else
          true
        end
      end

      private

      def doorkeeper_render_error
        error = doorkeeper_error
        error.raise_exception! if Doorkeeper.config.raise_on_errors?

        headers.merge!(error.headers.reject { |k| k == "Content-Type" })
        doorkeeper_render_error_with(error)
      end

      def doorkeeper_render_error_with(error)
        options = doorkeeper_render_options(error) || {}
        status = doorkeeper_status_for_error(
          error, options.delete(:respond_not_found_when_forbidden),
        )
        if options.blank?
          head status
        else
          options[:status] = status
          options[:layout] = false if options[:layout].nil?
          render options
        end
      end

      def doorkeeper_error
        error_attributes = { access_token_method: @_doorkeeper_access_token_method, dpop: @_doorkeeper_dpop }

        if doorkeeper_invalid_dpop_proof_response?
          OAuth::InvalidDPoPProofResponse.new(error_attributes)
        elsif doorkeeper_invalid_token_response?
          OAuth::InvalidTokenResponse.from_access_token(doorkeeper_token, error_attributes)
        else
          OAuth::ForbiddenTokenResponse.from_scopes(@_doorkeeper_scopes, error_attributes)
        end
      end

      def doorkeeper_render_options(error)
        if doorkeeper_invalid_token_response? || doorkeeper_invalid_dpop_proof_response?
          doorkeeper_unauthorized_render_options(error: error)
        else
          doorkeeper_forbidden_render_options(error: error)
        end
      end

      def doorkeeper_status_for_error(error, respond_not_found_when_forbidden)
        if respond_not_found_when_forbidden && error.status == :forbidden
          :not_found
        else
          error.status
        end
      end

      def doorkeeper_invalid_token_response?
        !doorkeeper_token || !doorkeeper_token.accessible? || !satisified_doorkeeper_token_dpop_binding?
      end

      def doorkeeper_invalid_dpop_proof_response?
        @_doorkeeper_access_token_method == :from_dpop_authorization && !doorkeeper_dpop_proof.valid?
      end

      def doorkeeper_dpop_proof
        @doorkeeper_dpop_proof ||= begin
          doorkeeper_authenticate3
          OAuth::DPoPProof.new(__doorkeeper_request__, @_doorkeeper_plaintext_token)
        end
      end

      def doorkeeper_token
        return @doorkeeper_token if defined?(@doorkeeper_token)

        doorkeeper_authenticate3
        @doorkeeper_token
      end

      def doorkeeper_authenticate3
        return @_doorkeeper_authenticate3 if defined?(@_doorkeeper_authenticate3)

        @_doorkeeper_authenticate3 = begin
          access_token_methods = if @_doorkeeper_dpop == :required
                                   %i[from_dpop_authorization]
                                 else
                                   Doorkeeper.config.access_token_methods
                                 end
          OAuth::Token.authenticate3(__doorkeeper_request__, *access_token_methods)
        end

        @_doorkeeper_access_token_method, @_doorkeeper_plaintext_token, @doorkeeper_token = @_doorkeeper_authenticate3
      end

      def __doorkeeper_request__
        request
      end
    end
  end
end
