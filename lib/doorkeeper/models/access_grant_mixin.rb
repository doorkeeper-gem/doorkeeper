module Doorkeeper
  module AccessGrantMixin
    extend ActiveSupport::Concern

    include OAuth::Helpers
    include Models::Expirable
    include Models::Revocable
    include Models::Accessible
    include Models::Scopes
    include ActiveModel::MassAssignmentSecurity if defined?(::ProtectedAttributes)

    included do
      belongs_to_options = {
        class_name: 'Doorkeeper::Application',
        inverse_of: :access_grants
      }
      if defined?(ActiveRecord::Base) && ActiveRecord::VERSION::MAJOR >= 5
        belongs_to_options[:optional] = true
      end

      belongs_to :application, belongs_to_options

      validates :resource_owner_id, :application_id, :token, :expires_in, :redirect_uri, presence: true
      validates :token, uniqueness: true

      before_validation :generate_token, on: :create

      def verify_code(code_verifier)
        return true unless code_challenge.present?
        return false unless code_verifier

        if code_challenge_method == 'S256'
          code_challenge == Base64.urlsafe_encode64(Digest::SHA256.digest(code_verifier))
        else
          code_challenge == code_verifier
        end
      end
    end

    module ClassMethods
      # Searches for Doorkeeper::AccessGrant record with the
      # specific token value.
      #
      # @param token [#to_s] token value (any object that responds to `#to_s`)
      #
      # @return [Doorkeeper::AccessGrant, nil] AccessGrant object or nil
      #   if there is no record with such token
      #
      def by_token(token)
        find_by(token: token.to_s)
      end
    end

    private

    # Generates token value with UniqueToken class.
    #
    # @return [String] token value
    #
    def generate_token
      self.token = UniqueToken.generate
    end
  end
end
