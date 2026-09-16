# frozen_string_literal: true

module Doorkeeper
  module ClientAuthentication
    # Credentials for a client that was already fully authenticated by its
    # authentication method (e.g. a verified private_key_jwt assertion), so
    # the client lookup must not run a secret comparison — there is no
    # secret, and the proof of identity has already been checked.
    class VerifiedCredentials < Credentials
      # Which client the method decided these credentials are for: one whose
      # keys came from a Client ID Metadata Document, or a registered
      # application's. nil where the method did not decide — every method but
      # private_key_jwt, and a host application's own.
      #
      # See +from_metadata_document?+ for why the answer travels with the
      # credentials rather than being asked again at lookup time.
      attr_reader :from_metadata_document

      # +authenticated_with+ is inherited from Credentials, where it is
      # documented. A strategy building these itself may name the method it
      # implements, which is what a caller invoking it directly reads; on the
      # request path Server overwrites it with the name of the strategy it
      # selected, so the record is the server's and not the strategy's word.
      # Either way a client whose metadata document selects one method is never
      # authenticated by another — see Doorkeeper::OAuth::Client.authenticate.
      def initialize(uid, authenticated_with: nil, from_metadata_document: nil)
        super(uid, nil)
        self.authenticated_with = authenticated_with
        @from_metadata_document = from_metadata_document
      end

      def pre_authenticated?
        true
      end

      # Whether the verification these credentials record was done against a
      # metadata document's keys (true) or a registered application's (false),
      # or was not a question the method asked (nil).
      #
      # Client.authenticate has to resolve the uid to a row of its own, and
      # what a uid resolves to can change in between: an application row
      # holding the URL can be registered or removed, and a materialized row's
      # stamp can be cleared to adopt it. The gap is not instantaneous — a
      # document client's keys are fetched over the network, which is up to
      # MAX_TOTAL_TIME of a window whoever serves the document decides the
      # width of — so the resolution honours the provenance recorded here
      # instead of deciding it a second time. Otherwise an assertion verified
      # against a document's keys could be resolved to the registered
      # application that came to hold the same URL, whose keys the signer
      # never had.
      def from_metadata_document?
        @from_metadata_document
      end
    end
  end
end
