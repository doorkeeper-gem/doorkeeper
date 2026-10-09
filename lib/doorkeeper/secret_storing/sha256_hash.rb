# frozen_string_literal: true

module Doorkeeper
  module SecretStoring
    ##
    # Plain text secret storing, which is the default
    # but also provides fallback lookup if
    # other secret storing mechanisms are enabled.
    class Sha256Hash < Base
      ##
      # Return the value to be stored by the database
      # @param plain_secret The plain secret input / generated
      def self.transform_secret(plain_secret)
        ::Digest::SHA256.hexdigest plain_secret
      end

      ##
      # Determines whether this strategy supports restoring
      # secrets from the database. This allows detecting users
      # trying to use a non-restorable strategy with +reuse_access_tokens+.
      def self.allows_restoring_secrets?
        false
      end

      ##
      # +Digest::SHA256.hexdigest+ writes 64 lower case hex characters and
      # nothing else, and its shape is all there is to go on: a hash cannot be
      # reversed to check, and a `fallback: :plain` restore hands back the
      # column itself, so there is no plaintext to re-derive from and compare
      # against.
      #
      # A plain secret of that shape is therefore read as this strategy's own
      # and retained as stored, plaintext and all, until the next
      # authentication with it upgrades the column. That is not hypothetical:
      # `default_generator_method :hex` produces exactly 64 lower case hex
      # characters (`SecureRandom.hex(32)`), so under that setting a legacy
      # plain secret is indistinguishable from a digest. The README says so
      # where it describes what a rotation re-derives.
      #
      # Answering the other way round is worse. A digest re-derived under this
      # strategy is the hash of a hash, which is not what any client holds, so
      # the retained secret would authenticate nobody — a grace period that
      # silently does nothing, in place of one that stores more than it should
      # for as long as it lasts.
      def self.recognizes_stored_secret?(stored)
        /\A[0-9a-f]{64}\z/.match?(stored.to_s)
      end
    end
  end
end
