# frozen_string_literal: true

module Doorkeeper
  module Models
    ##
    # Hashable finder to provide lookups for input plaintext values which are
    # mapped to their hashes before lookup.
    module Hashable
      extend ActiveSupport::Concern

      delegate :perform_secret_hashing?,
               :hashed_or_plain_token,
               to: :class

      # :nodoc
      module ClassMethods
        # Allow to override the hashing method by the including module
        attr_accessor :secret_hash_function, :secret_comparer

        # Compare the given plaintext with the secret
        #
        # @param input [String]
        #   The plain input to compare.
        #
        # @param secret [String]
        #   The secret value to compare with.
        #
        # @return [Boolean]
        #   If hashing is enabled: Whether the secret equals hashed input
        #   If hashing is disabled: Whether input matches secret
        #
        def secret_matches?(input, secret)
          unless perform_secret_hashing?
            return ActiveSupport::SecurityUtils.secure_compare input, secret
          end

          (secret_comparer || method(:default_comparer))
            .call(input, secret)
        end

        # Returns an instance of the Doorkeeper::AccessToken with
        # specific token value.
        #
        # @param attr [Symbol]
        #   The token attribute we're looking with.
        #
        # @param token [#to_s]
        #   token value (any object that responds to `#to_s`)
        #
        # @return [Doorkeeper::AccessToken, nil] AccessToken object or nil
        #   if there is no record with such token
        #
        def find_by_plaintext_token(attr, token)
          token = token.to_s

          find_by(attr => hashed_or_plain_token(token)) ||
            find_by_fallback_token(attr, token)
        end

        # Allow looking up previously plain tokens as a fallback
        # IFF respective options are enabled
        #
        # @param attr [Symbol]
        #   The token attribute we're looking with.
        #
        # @param token [#to_s]
        #   token value (any object that responds to `#to_s`)
        #
        # @return [Doorkeeper::AccessToken, nil] AccessToken object or nil
        #   if there is no record with such token
        #
        def find_by_fallback_token(attr, token)
          return nil unless perform_secret_hashing?
          return nil unless Doorkeeper.configuration.fallback_to_plain_secrets?

          find_by(attr => token).tap do |fallback|
            upgrade_fallback_value fallback, attr
          end
        end

        # Hash the given input token
        #
        # @param plain_token [String]
        #   The plain text token to hash.
        #
        # @return [String]
        #   IFF secret hashing enabled, the hashed token,
        #   otherwise returns the plain token.
        def hashed_or_plain_token(plain_token)
          if perform_secret_hashing?
            (secret_hash_function || method(:default_hash_function))
              .call plain_token
          else
            plain_token
          end
        end

        # Allow implementations in ORMs to replace a plain
        # value falling back to to avoid it remaining as plain text.
        #
        # @param instance
        #   An instance of this model with a plain value token.
        #
        # @param attr
        #   The token attribute to upgrade
        #
        def upgrade_fallback_value(instance, attr)
          plain_token = instance.public_send attr
          instance.update_column(attr, hashed_or_plain_token(plain_token))
        end

        # Including classes can override this function to
        # disable or enable secret hashing dynamically
        def perform_secret_hashing?
          true
        end

        # Return a default hashing function to be used when including
        # module or user does not specify what to use
        # @param plain_token [String]
        #   The plain text token to hash.
        #
        # @return [String] Hashed plain text token
        #
        def default_hash_function(plain_token)
          ::Digest::SHA256.hexdigest plain_token
        end

        # Return a default comparer for the given hash function
        def default_comparer(plain, secret)
          hashed = hashed_or_plain_token(plain)
          ActiveSupport::SecurityUtils.secure_compare hashed, secret
        end
      end
    end
  end
end
