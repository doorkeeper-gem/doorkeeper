# frozen_string_literal: true
module Authentication
  module Lockable
    extend ActiveSupport::Concern

    included do
      attr_accessor :unlock_token
    end

    def increase_failed_attempts
      self.failed_attempts += 1
      self.locked_at = Time.now if need_lock?
      save
    end

    def prepare_unlock
      self.unlock_token = SecureRandom.urlsafe_base64 40
      self.unlock_digest = BCrypt::Password.create unlock_token
      save

      UserMailer.unlock_email(email, unlock_token).deliver_later
    end

    def lock
      self.locked_at = Time.now
      save
    end

    def unlock
      self.unlock_digest = nil
      self.unlock_sent_at = nil
      self.locked_at = nil
      save
    end

    def need_lock?
      self.failed_attempts >= 3
    end

    def unlock_valid?(unlock_token)
      pending_unlock? &&
        !unlock_expired? &&
        BCrypt::Password.new(unlock_digest).is_password?(unlock_token)
    end

    def unlock_expired?
      !Time.now.between? unlock_sent_at,
                         unlock_sent_at + 2.hours
    end

    def pending_unlock?
      unlock_digest.present? &&
        unlock_sent_at.present? &&
        locked_at.present?
    end

    def locked?
      locked_at.present?
    end

    def unlocked?
      !locked?
    end
  end
end
