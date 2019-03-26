# frozen_string_literal: true

module Doorkeeper
  module OAuth
    module Helpers
      module UniqueToken
        def self.generate(options = {})
          # Access Token value must be 1*VSCHAR or
          # 1*( ALPHA / DIGIT / "-" / "." / "_" / "~" / "+" / "/" ) *"="
          #
          # @see https://tools.ietf.org/html/rfc6749#appendix-A.12
          # @see https://tools.ietf.org/html/rfc6750#section-2.1
          #
          generator_method = options.delete(:generator) || SecureRandom.method(self.generator_method)
          token_size       = options.delete(:size)      || 32
          generator_method.call(token_size)
        end

        # Generator method for default generator class (SecureRandom)
        #
        def self.generator_method
          Doorkeeper.configuration.default_generator_method
        end
      end
    end
  end
end
