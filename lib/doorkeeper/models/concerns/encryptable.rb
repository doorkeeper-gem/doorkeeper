# frozen_string_literal: true

module Doorkeeper
  module Models
    module Encryptable
      extend ActiveSupport::Concern

      delegate :encrypt_token_secrets?,
               :encrypt_token,
               :decrypt_token,
               :encrypted_column,
               to: :class

      module ClassMethods
        def encrypt_token_secrets?
          Doorkeeper.configuration.encrypt_token_secrets?
        end

        def encrypt_token(plain_token)
          default_encryption_box.encrypt(plain_token)
        end

        def decrypt_token(encrypted_token)
          default_encryption_box.decrypt(encrypted_token)
        end

        def default_encryption_box
          @default_encryption_box ||=
            Doorkeeper.configuration.encryption_box.call
        end

        def encrypted_column(attribute)
          "#{Doorkeeper.configuration.encryption_prefix_column}_#{attribute}"
        end
      end
    end
  end
end
