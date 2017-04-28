# frozen_string_literal: true
module Authentication
  module Recoverable

    attr_accessor :reset_password_token

    def prepare_reset_password
      self.reset_password_token = SecureRandom.urlsafe_base64 40
      self.reset_password_digest = BCrypt::Password.create reset_password_token
      save

      UserMailer.reset_password_email(email, reset_password_token).deliver_later
    end

    def reset_password(password, password_confirmation)
      self.reset_password_digest = nil
      self.reset_password_sent_at = nil
      self.password = password
      self.password_confirmation = password_confirmation
      save

      UserMailer.password_changed_email(email).deliver_later
    end

    def reset_password_valid?(reset_password_token)
      pending_reset_password? &&
        !reset_password_expired? &&
        BCrypt::Password.new(reset_password_digest).is_password?(reset_password_token)
    end

    def reset_password_expired?
      !Time.now.between? reset_password_sent_at,
                         reset_password_sent_at + 2.hours
    end

    def pending_reset_password?
      reset_password_digest.present? &&
        reset_password_sent_at.present?
    end
  end
end
