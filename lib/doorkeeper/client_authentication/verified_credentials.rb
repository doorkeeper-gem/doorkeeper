# frozen_string_literal: true

module Doorkeeper
  module ClientAuthentication
    # Credentials for a client that was already fully authenticated by its
    # authentication method (e.g. a verified private_key_jwt assertion), so
    # the client lookup must not run a secret comparison — there is no
    # secret, and the proof of identity has already been checked.
    class VerifiedCredentials < Credentials
      def initialize(uid)
        super(uid, nil)
      end

      def pre_authenticated?
        true
      end
    end
  end
end
