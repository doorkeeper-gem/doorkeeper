module Doorkeeper
  class AccessGrant < ActiveRecord::Base
    self.table_name = "#{table_name_prefix}oauth_access_grants#{table_name_suffix}".to_sym

    include AccessGrantMixin
    include ActiveModel::MassAssignmentSecurity if defined?(::ProtectedAttributes)

    belongs_to_options = {
      class_name: 'Doorkeeper::Application',
      inverse_of: :access_grants
    }

    if defined?(ActiveRecord::Base) && ActiveRecord::VERSION::MAJOR >= 5
      belongs_to_options[:optional] = true
    end

    belongs_to :application, belongs_to_options

    validates :resource_owner_id,
              :application_id,
              :token,
              :expires_in,
              :redirect_uri,
              presence: true

    validates :token, uniqueness: true

    before_validation :generate_token, on: :create

    # Keep a reference to the generated token during generation
    # of this access grant. The actual token may be mapped by
    # the configuration hasher and may not be available in plaintext.
    #
    # If hash tokens are enabled, this will return nil on fetched tokens
    def plaintext_token
      if perform_secret_hashing?
        @raw_token
      else
        token
      end
    end

    private

    # Generates token value with UniqueToken class.
    #
    # @return [String] token value
    #
    def generate_token
      @raw_token = UniqueToken.generate
      self.token = hashed_or_plain_token(@raw_token)
    end
  end
end
