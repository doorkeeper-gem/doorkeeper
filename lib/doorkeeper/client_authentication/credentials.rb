# frozen_string_literal: true

module Doorkeeper
  module ClientAuthentication
    Credentials = Struct.new(:uid, :secret) do
      # Public clients may have their secret blank, but "credentials" are
      # still present as long as the uid is present.
      delegate :blank?, to: :uid

      # The token endpoint authentication method that produced these
      # credentials, as the name is registered with IANA and therefore as a
      # client naming it in metadata would write it — "client_secret_basic",
      # "private_key_jwt", "tls_client_auth" and so on. That is the strategy's
      # own knowledge, not its registration key in Doorkeeper's registry,
      # which a host application chooses freely and which need not match.
      #
      # Doorkeeper::Server stamps it from the strategy it selected, so a
      # caller that must know *how* a client authenticated does not depend on
      # each strategy to volunteer it. A strategy that declares no IANA name
      # leaves this nil, which such a caller has to treat as "unknown".
      attr_accessor :authenticated_with
    end
  end
end
