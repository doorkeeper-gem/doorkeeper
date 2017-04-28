# frozen_string_literal: true
module Doorkeeper
  module Models
    module Confirmable

      attr_accessor :confirmation_token

      def prepare_confirmation
        self.confirmation_token = SecureRandom.urlsafe_base64 40
        self.confirmation_digest = BCrypt::Password.create confirmation_token
        save

        UserMailer.confirmation_email(email, confirmation_token).deliver_later
      end

      def confirm
        self.confirmation_digest = nil
        self.confirmation_sent_at = nil
        self.confirmed_at = Time.now
        save
      end

      def confirmation_valid?(confirmation_token)
        pending_confirmation? &&
          !confirmation_expired? &&
          BCrypt::Password.new(confirmation_digest).is_password?(confirmation_token)
      end

      def confirmation_expired?
        !Time.now.between? confirmation_sent_at,
                           confirmation_sent_at + 2.hours
      end

      def pending_confirmation?
        confirmation_digest.present? &&
          confirmation_sent_at.present?
      end

      def confirmed?
        confirmation_digest.blank? &&
          confirmation_sent_at.blank? &&
          confirmed_at.present?
      end

      def unconfirmed?
        !confirmed?
      end
    end
  end
end
