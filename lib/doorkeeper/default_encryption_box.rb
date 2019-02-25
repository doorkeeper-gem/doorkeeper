# frozen_string_literal: true

module Doorkeeper
  class DefaultEncryptionBox
    attr_reader :encryptor

    def initialize(key)
      @encryptor = ActiveSupport::MessageEncryptor.new(
        key[0, ActiveSupport::MessageEncryptor.key_len]
      )
    end

    def encrypt(plaintext)
      encryptor.encrypt_and_sign(plaintext)
    end

    def decrypt(ciphertext)
      encryptor.decrypt_and_verify(ciphertext)
    end
  end
end
