# frozen_string_literal: true

module Doorkeeper
  module OAuth
    class Client
      Credentials = Struct.new(:uid, :secret) do
        class << self
          def from_request(request, *credentials_methods)
            credentials_methods.inject(nil) do |_, method|
              method = self.method(method) if method.is_a?(Symbol)
              credentials = Credentials.new(*method.call(request))
              break credentials if credentials.present?
            end
          end

          def from_params(request)
            request.parameters.values_at(:client_id, :client_secret)
          end

          def from_basic(request)
            authorization = request.authorization
            return unless authorization.present? && authorization =~ /^Basic (.*)/m

            Base64.decode64(Regexp.last_match(1)).split(/:/, 2)
          end
        end

        # Public clients may have their secret blank, but "credentials" are
        # still present
        delegate :blank?, to: :uid
      end
    end
  end
end
