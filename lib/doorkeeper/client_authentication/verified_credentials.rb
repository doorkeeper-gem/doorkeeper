# frozen_string_literal: true

module Doorkeeper
  module ClientAuthentication
    # Credentials for a client that was already fully authenticated by its
    # authentication method (e.g. a verified private_key_jwt assertion), so
    # the client lookup must not run a secret comparison — there is no
    # secret, and the proof of identity has already been checked.
    class VerifiedCredentials < Credentials
      # +authenticated_with+ is inherited from Credentials, where it is
      # documented. A strategy building these itself may name the method it
      # implements, which is what a caller invoking it directly reads; on the
      # request path Server overwrites it with the name of the strategy it
      # selected, so the record is the server's and not the strategy's word.
      # Either way a client whose metadata document selects one method is never
      # authenticated by another — see Doorkeeper::OAuth::Client.authenticate.
      def initialize(uid, authenticated_with: nil)
        super(uid, nil)
        self.authenticated_with = authenticated_with
      end

      def pre_authenticated?
        true
      end
    end
  end
end
