# frozen_string_literal: true

require 'bcrypt'

module Doorkeeper
  module ApplicationMixin
    extend ActiveSupport::Concern

    include OAuth::Helpers
    include Models::Orderable
    include Models::Hashable
    include Models::Scopes

    included do
      # Use BCrypt as the hashing function for applications
      self.secret_hash_function = lambda do |plain_token|
        BCrypt::Password.create(plain_token.to_s)
      end

      # Also need to override the comparer function for BCrypt
      self.secret_comparer = lambda do |plain, secret|
        begin
          BCrypt::Password.new(secret.to_s) == plain.to_s
        rescue BCrypt::Errors::InvalidHash
          false
        end
      end
    end

    # :nodoc
    module ClassMethods
      # We want to perform secret hashing whenever the user
      # enables the configuration option +hash_application_secrets+
      def perform_secret_hashing?
        Doorkeeper.configuration.hash_application_secrets?
      end

      # Returns an instance of the Doorkeeper::Application with
      # specific UID and secret.
      #
      # Public/Non-confidential applications will only find by uid if secret is
      # blank.
      #
      # @param uid [#to_s] UID (any object that responds to `#to_s`)
      # @param secret [#to_s] secret (any object that responds to `#to_s`)
      #
      # @return [Doorkeeper::Application, nil] Application instance or nil
      #   if there is no record with such credentials
      #
      def by_uid_and_secret(uid, secret)
        app = by_uid(uid)
        return unless app
        return app if secret.blank? && !app.confidential?
        return unless app.secret_matches?(secret)
        app
      end

      # Returns an instance of the Doorkeeper::Application with specific UID.
      #
      # @param uid [#to_s] UID (any object that responds to `#to_s`)
      #
      # @return [Doorkeeper::Application, nil] Application instance or nil
      #   if there is no record with such UID
      #
      def by_uid(uid)
        find_by(uid: uid.to_s)
      end
    end

    # Set an application's valid redirect URIs.
    #
    # @param uris [String, Array] Newline-separated string or array the URI(s)
    #
    # @return [String] The redirect URI(s) seperated by newlines.
    def redirect_uri=(uris)
      super(uris.is_a?(Array) ? uris.join("\n") : uris)
    end

    # Check whether the given plain text secret matches our stored secret
    #
    # @param input [#to_s] Plain secret provided by user
    #        (any object that responds to `#to_s`)
    #
    # @return [true] Whether the given secret matches the stored secret
    #                of this application.
    #
    def secret_matches?(input)
      # return false if either is nil, since secure_compare depends on strings
      # but Application secrets MAY be nil depending on confidentiality.
      return false if input.nil? || secret.nil?

      # When matching the secret by comparer function, all is well.
      return true if self.class.secret_matches?(input, secret)

      # When fallback lookup is enabled, ensure applications
      # with plain secrets can still be found
      if Doorkeeper.configuration.fallback_to_plain_secrets?
        ActiveSupport::SecurityUtils.secure_compare(input, secret)
      else
        false
      end
    end
  end
end
