require 'doorkeeper/validations'
require 'doorkeeper/oauth/scopes'
require 'doorkeeper/oauth/helpers/scope_checker'

module Doorkeeper
  module OAuth
    class ClientCredentialsRequest
      class Validation
        include Validations
        include OAuth::Helpers

        validate :client, error: :invalid_client
        validate :scopes, error: :invalid_scope

        def initialize(server, request)
          @server, @request = server, request
          validate
        end

        private

        def validate_client
          @request.client.present?
        end

        def validate_scopes
          return true unless @request.original_scopes.present?
          ScopeChecker.valid?(@request.original_scopes, @server.scopes)
        end
      end
    end
  end
end
