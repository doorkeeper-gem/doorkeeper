# frozen_string_literal: true
module Doorkeeper
  module Models
    module Omniauthable
      # Find first or create user from OAuth2 credentials
      #
      # @param [Hash, request.env['omniauth.auth']] auth OAuth2 credentials hash from provider
      # @return [self]
      def self.from_omniauth(auth)
        user = unscoped.where(provider: auth.provider, uid: auth.uid).first_or_create do |u|
          u.from_omniauth(auth)
        end
        user.update_provider_token(auth)
        user
      end

      # Assign variables from OAuth2 credentials
      #
      # @param [Hash, request.env['omniauth.auth']] auth OAuth2 credentials hash from provider
      # @return [self]
      def from_omniauth(auth)
        self.email = auth.info.email
        self.password = Devise.friendly_token[0, 20]
        self.avatar = URI.parse(auth.info.image + '?type=large')
        # self.skip_confirmation!
      end

      # Update provider token
      #
      # @param [Hash, request.env['omniauth.auth']] auth OAuth2 credentials hash from provider
      # @return [self]
      def update_provider_token(auth)
        update(provider_token: auth.credentials.token)
      end
    end
  end
end
