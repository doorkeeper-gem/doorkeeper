# frozen_string_literal: true

module Doorkeeper
  class Server
    attr_reader :context

    def initialize(context)
      @context = context
    end

    def client_authentication_method_for_request
      Request.client_authentication_method(context.request)
    end

    def authorization_request(strategy)
      klass = Request.authorization_strategy(strategy)
      klass.new(self)
    end

    def token_request(strategy)
      klass = Request.token_strategy(strategy)
      klass.new(self)
    end

    # TODO: context should be the request
    def parameters
      context.request.parameters
    end

    def client
      @client ||= OAuth::Client.authenticate(credentials)
    end

    def current_resource_owner
      context.send :current_resource_owner
    end

    # TODO: Use configuration and evaluate proper context on block
    def resource_owner
      context.send :resource_owner_from_credentials
    end

    def credentials
      return @credentials if defined?(@credentials)

      strategy = client_authentication_method_for_request
      credentials = strategy.authenticate(context.request)

      # Record which method produced them, so a caller that must know *how* a
      # client authenticated — Client.authenticate holding a metadata document
      # client to the one method its document names — reads it from the
      # credentials rather than trusting each strategy to volunteer it. A
      # strategy that already named the method it implements keeps its answer;
      # one declaring no IANA name leaves this nil.
      if credentials.respond_to?(:authenticated_with) && credentials.authenticated_with.blank?
        credentials.authenticated_with = auth_method_name_for(strategy)
      end

      @credentials = credentials
    end

    # A strategy declares the IANA name of the method it implements, which is
    # its own knowledge — unlike its registration key, which a host
    # application chooses freely.
    def auth_method_name_for(strategy)
      strategy.auth_method_name if strategy.respond_to?(:auth_method_name)
    end
    private :auth_method_name_for
  end
end
