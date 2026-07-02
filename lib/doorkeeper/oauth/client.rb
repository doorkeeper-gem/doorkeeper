# frozen_string_literal: true

require "doorkeeper/client_authentication/credentials"

module Doorkeeper
  module OAuth
    class Client
      # @deprecated Moved to +Doorkeeper::ClientAuthentication::Credentials+.
      #   This alias keeps the long-standing +Doorkeeper::OAuth::Client::Credentials+
      #   constant resolvable for one release so referencing code does not raise
      #   +NameError+; update references to the new constant. Note the legacy
      #   +.from_request+/+.from_basic+/+.from_params+ class methods are gone —
      #   client credential extraction now goes through the client authentication
      #   registry (RFC 6749 §2.3). Marked with +deprecate_constant+, so Ruby
      #   warns on access when deprecation warnings are enabled
      #   (+Warning[:deprecated] = true+ or +-W:deprecated+).
      Credentials = Doorkeeper::ClientAuthentication::Credentials
      deprecate_constant :Credentials

      attr_reader :application

      delegate :id, :name, :uid, :redirect_uri, :scopes, :confidential, to: :@application

      def initialize(application)
        @application = application
      end

      def self.find(uid, method = Doorkeeper.config.application_model.method(:by_uid))
        return unless (application = method.call(uid))

        new(application)
      end

      def self.authenticate(credentials, method = Doorkeeper.config.application_model.method(:by_uid_and_secret))
        return if credentials.blank?
        return unless (application = method.call(credentials.uid, credentials.secret))

        new(application)
      end
    end
  end
end
