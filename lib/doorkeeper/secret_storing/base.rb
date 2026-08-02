# frozen_string_literal: true

module Doorkeeper
  module SecretStoring
    ##
    # Base class for secret storing, including common helpers
    class Base
      ##
      # Return the value to be stored by the database
      # used for looking up a database value.
      # @param plain_secret The plain secret input / generated
      def self.transform_secret(_plain_secret)
        raise NotImplementedError
      end

      ##
      # Transform and store the given secret attribute => value
      # pair used for safely storing the attribute
      # @param resource The model instance being modified
      # @param attribute The secret attribute
      # @param plain_secret The plain secret input / generated
      def self.store_secret(resource, attribute, plain_secret)
        transformed_value = transform_secret(plain_secret)
        resource.public_send(:"#{attribute}=", transformed_value)

        transformed_value
      end

      ##
      # Return the restored value from the database
      # @param resource The resource instance to act on
      # @param attribute The secret attribute to restore
      # as retrieved from the database.
      def self.restore_secret(_resource, _attribute)
        raise NotImplementedError
      end

      ##
      # Determines whether this strategy supports restoring
      # secrets from the database. This allows detecting users
      # trying to use a non-restorable strategy with +reuse_access_tokens+.
      def self.allows_restoring_secrets?
        false
      end

      ##
      # Whether +stored+ is a value this strategy wrote, asked of a stored
      # value with no plaintext to compare it against.
      #
      # Answered +true+ here, which is the answer that changes nothing: a
      # caller uses this to decide whether a value is worth re-deriving under
      # the active strategy, and a strategy that cannot tell its own output
      # apart from anyone else's is better left alone than re-encoded on a
      # guess. Overridden by the strategies whose output has a shape --
      # +BCrypt+ and +Sha256Hash+ -- so that a value written by a fallback
      # strategy can be recognised as not theirs.
      #
      # Optional for a custom strategy, which is duck typed everywhere else it
      # is used: one that does not define this at all -- because it does not
      # subclass this class -- is read as answering +true+, the same way.
      #
      # @param stored [String] a stored secret value
      #
      # @return [Boolean]
      def self.recognizes_stored_secret?(_stored)
        true
      end

      ##
      # Determines what secrets this strategy is applicable for
      def self.validate_for(model)
        valid = %i[token application]
        return true if valid.include?(model.to_sym)

        raise ArgumentError, "'#{name}' can not be used for #{model}."
      end

      ##
      # Securely compare the given +input+ value with a +stored+ value
      # processed by +transform_secret+.
      def self.secret_matches?(input, stored)
        transformed_input = transform_secret(input)
        ActiveSupport::SecurityUtils.secure_compare transformed_input, stored
      end
    end
  end
end
