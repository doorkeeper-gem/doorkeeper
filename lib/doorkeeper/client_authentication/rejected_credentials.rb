# frozen_string_literal: true

module Doorkeeper
  module ClientAuthentication
    # Credentials for a request whose client authentication was supplied and
    # refused by its authentication method. Returning nothing instead would
    # make the request look like one that carries no client authentication,
    # which some grants accept (RFC 6749 §6 lets a public client refresh
    # without any), so the refusal would be reported as something else, or
    # not at all.
    #
    # They name no client and carry no secret, so nothing can be looked up
    # with them, yet they are present: a request that carries them fails
    # client authentication (invalid_client, RFC 6749 §5.2).
    class RejectedCredentials < Credentials
      def initialize
        super(nil, nil)
      end

      def blank?
        false
      end

      def rejected?
        true
      end
    end
  end
end
