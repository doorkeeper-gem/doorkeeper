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
      # nothing else. A plain secret that happens to look like one is read as
      # this strategy's own, which is the harmless direction: the value is
      # then left as it is stored, exactly as it was before this predicate
      # existed.
      def self.recognizes_stored_secret?(stored)
        /\A[0-9a-f]{64}\z/.match?(stored.to_s)
      end
    end
  end
end
