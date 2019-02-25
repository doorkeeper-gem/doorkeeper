# frozen_string_literal: true

module Doorkeeper
  module AccessTokenMixin
    extend ActiveSupport::Concern

    include OAuth::Helpers
    include Models::Expirable
    include Models::Reusable
    include Models::Revocable
    include Models::Accessible
    include Models::Orderable
    include Models::Hashable
    include Models::Encryptable
    include Models::Scopes

    module ClassMethods
      # Returns an instance of the Doorkeeper::AccessToken with
      # specific plain text token value.
      #
      # @param token [#to_s]
      #   Plain text token value (any object that responds to `#to_s`)
      #
      # @return [Doorkeeper::AccessToken, nil] AccessToken object or nil
      #   if there is no record with such token
      #
      def by_token(token)
        find_by_plaintext_token(:token, token)
      end

      # Returns an instance of the Doorkeeper::AccessToken
      # with specific token value.
      #
      # @param refresh_token [#to_s]
      #   refresh token value (any object that responds to `#to_s`)
      #
      # @return [Doorkeeper::AccessToken, nil] AccessToken object or nil
      #   if there is no record with such refresh token
      #
      def by_refresh_token(refresh_token)
        find_by_plaintext_token(:refresh_token, refresh_token)
      end

      # We want to perform secret hashing whenever the user
      # enables the configuration option +hash_token_secrets+
      def perform_secret_hashing?
        Doorkeeper.configuration.hash_token_secrets?
      end

      # Revokes AccessToken records that have not been revoked and associated
      # with the specific Application and Resource Owner.
      #
      # @param application_id [Integer]
      #   ID of the Application
      # @param resource_owner [ActiveRecord::Base]
      #   instance of the Resource Owner model
      #
      def revoke_all_for(application_id, resource_owner, clock = Time)
        where(application_id: application_id,
              resource_owner_id: resource_owner.id,
              revoked_at: nil)
          .update_all(revoked_at: clock.now.utc)
      end

      # Looking for not revoked Access Token with a matching set of scopes
      # that belongs to specific Application and Resource Owner.
      #
      # @param application [Doorkeeper::Application]
      #   Application instance
      # @param resource_owner_or_id [ActiveRecord::Base, Integer]
      #   Resource Owner model instance or it's ID
      # @param scopes [String, Doorkeeper::OAuth::Scopes]
      #   set of scopes
      #
      # @return [Doorkeeper::AccessToken, nil] Access Token instance or
      #   nil if matching record was not found
      #
      def matching_token_for(application, resource_owner_or_id, scopes)
        resource_owner_id = if resource_owner_or_id.respond_to?(:to_key)
                              resource_owner_or_id.id
                            else
                              resource_owner_or_id
                            end

        tokens = authorized_tokens_for(application.try(:id), resource_owner_id)
        tokens.detect do |token|
          scopes_match?(token.scopes, scopes, application.try(:scopes))
        end
      end

      # Checks whether the token scopes match the scopes from the parameters
      #
      # @param token_scopes [#to_s]
      #   set of scopes (any object that responds to `#to_s`)
      # @param param_scopes [Doorkeeper::OAuth::Scopes]
      #   scopes from params
      # @param app_scopes [Doorkeeper::OAuth::Scopes]
      #   Application scopes
      #
      # @return [Boolean] true if the param scopes match the token scopes,
      #   and all the param scopes are defined in the application (or in the
      #   server configuration if the application doesn't define any scopes),
      #   and false in other cases
      #
      def scopes_match?(token_scopes, param_scopes, app_scopes)
        return true if token_scopes.empty? && param_scopes.empty?

        (token_scopes.sort == param_scopes.sort) &&
          Doorkeeper::OAuth::Helpers::ScopeChecker.valid?(
            scope_str: param_scopes.to_s,
            server_scopes: Doorkeeper.configuration.scopes,
            app_scopes: app_scopes
          )
      end

      # Looking for not expired AccessToken record with a matching set of
      # scopes that belongs to specific Application and Resource Owner.
      # If it doesn't exists - then creates it.
      #
      # @param application [Doorkeeper::Application]
      #   Application instance
      # @param resource_owner_id [ActiveRecord::Base, Integer]
      #   Resource Owner model instance or it's ID
      # @param scopes [#to_s]
      #   set of scopes (any object that responds to `#to_s`)
      # @param expires_in [Integer]
      #   token lifetime in seconds
      # @param use_refresh_token [Boolean]
      #   whether to use the refresh token
      #
      # @return [Doorkeeper::AccessToken] existing record or a new one
      #
      def find_or_create_for(application, resource_owner_id, scopes, expires_in, use_refresh_token)
        if Doorkeeper.configuration.reuse_access_token
          access_token = matching_token_for(application, resource_owner_id, scopes)

          return access_token if access_token && access_token.reusable?
        end

        create!(
          application_id:    application.try(:id),
          resource_owner_id: resource_owner_id,
          scopes:            scopes.to_s,
          expires_in:        expires_in,
          use_refresh_token: use_refresh_token
        )
      end

      # Looking for not revoked Access Token records that belongs to specific
      # Application and Resource Owner.
      #
      # @param application_id [Integer]
      #   ID of the Application model instance
      # @param resource_owner_id [Integer]
      #   ID of the Resource Owner model instance
      #
      # @return [Doorkeeper::AccessToken] array of matching AccessToken objects
      #
      def authorized_tokens_for(application_id, resource_owner_id)
        ordered_by(:created_at, :desc)
          .where(application_id: application_id,
                 resource_owner_id: resource_owner_id,
                 revoked_at: nil)
      end

      # Convenience method for backwards-compatibility, return the last
      # matching token for the given Application and Resource Owner.
      #
      # @param application_id [Integer]
      #   ID of the Application model instance
      # @param resource_owner_id [Integer]
      #   ID of the Resource Owner model instance
      #
      # @return [Doorkeeper::AccessToken, nil] matching AccessToken object or
      #   nil if nothing was found
      #
      def last_authorized_token_for(application_id, resource_owner_id)
        authorized_tokens_for(application_id, resource_owner_id).first
      end
    end

    # Access Token type: Bearer.
    # @see https://tools.ietf.org/html/rfc6750
    #   The OAuth 2.0 Authorization Framework: Bearer Token Usage
    #
    def token_type
      'Bearer'
    end

    def use_refresh_token?
      @use_refresh_token ||= false
      !!@use_refresh_token
    end

    # JSON representation of the Access Token instance.
    #
    # @return [Hash] hash with token data
    def as_json(_options = {})
      {
        resource_owner_id:  resource_owner_id,
        scope:              scopes,
        expires_in:         expires_in_seconds,
        application:        { uid: application.try(:uid) },
        created_at:         created_at.to_i
      }
    end

    # Indicates whether the token instance have the same credential
    # as the other Access Token.
    #
    # @param access_token [Doorkeeper::AccessToken] other token
    #
    # @return [Boolean] true if credentials are same of false in other cases
    #
    def same_credential?(access_token)
      application_id == access_token.application_id &&
        resource_owner_id == access_token.resource_owner_id
    end

    # Indicates if token is acceptable for specific scopes.
    #
    # @param scopes [Array<String>] scopes
    #
    # @return [Boolean] true if record is accessible and includes scopes or
    #   false in other cases
    #
    def acceptable?(scopes)
      accessible? && includes_scope?(*scopes)
    end

    # We keep a volatile copy of the raw refresh token for initial communication
    # The stored refresh_token may be mapped and not available in cleartext.
    def plaintext_refresh_token
      if encrypt_token_secrets?
        @raw_refresh_token ||=
          decrypt_token(read_attribute(encrypted_column(:refresh_token)))
      elsif perform_secret_hashing?
        @raw_refresh_token
      else
        refresh_token
      end
    end

    # We keep a volatile copy of the raw token for initial communication
    # The stored refresh_token may be mapped and not available in cleartext.
    def plaintext_token
      if encrypt_token_secrets?
        @raw_token ||= decrypt_token(read_attribute(encrypted_column(:token)))
      elsif perform_secret_hashing?
        @raw_token
      else
        token
      end
    end

    private

    # Generates refresh token with UniqueToken generator.
    #
    # @return [String] refresh token value
    #
    def generate_refresh_token
      @raw_refresh_token = UniqueToken.generate
      self.refresh_token = hashed_or_plain_token(@raw_refresh_token)
      if encrypt_token_secrets?
        assign_attributes(
          encrypted_column(:refresh_token) => encrypt_token(@raw_refresh_token)
        )
      end

      @raw_refresh_token
    end

    # Generates and sets the token value with the
    # configured Generator class (see Doorkeeper.configuration).
    #
    # @return [String] generated token value
    #
    # @raise [Doorkeeper::Errors::UnableToGenerateToken]
    #   custom class doesn't implement .generate method
    # @raise [Doorkeeper::Errors::TokenGeneratorNotFound]
    #   custom class doesn't exist
    #
    def generate_token
      self.created_at ||= Time.now.utc

      @raw_token = token_generator.generate(
        resource_owner_id: resource_owner_id,
        scopes: scopes,
        application: application,
        expires_in: expires_in,
        created_at: created_at
      )

      self.token = hashed_or_plain_token(@raw_token)
      if encrypt_token_secrets?
        assign_attributes(encrypted_column(:token) => encrypt_token(@raw_token))
      end

      @raw_token
    end

    def token_generator
      generator_name = Doorkeeper.configuration.access_token_generator
      generator = generator_name.constantize

      return generator if generator.respond_to?(:generate)

      raise Errors::UnableToGenerateToken, "#{generator} does not respond to `.generate`."
    rescue NameError
      raise Errors::TokenGeneratorNotFound, "#{generator_name} not found"
    end
  end
end
