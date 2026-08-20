# frozen_string_literal: true

module Doorkeeper
  class AuthorizationsController < Doorkeeper::ApplicationController
    before_action :validate_client,
                  only: :new,
                  if: -> { Doorkeeper.config.validate_client_before_resource_owner_authentication? }
    before_action :authenticate_resource_owner!

    def new
      if pre_auth.authorizable?
        render_success
      else
        render_error
      end
    end

    def create
      redirect_or_render(authorize_response)
    end

    def destroy
      redirect_or_render(authorization.deny)
    rescue Doorkeeper::Errors::InvalidTokenStrategy => e
      error_response = get_error_response_from_exception(e)

      if Doorkeeper.configuration.api_only
        render json: error_response.body, status: :bad_request
      else
        render :error, locals: { error_response: error_response }
      end
    end

    private

    def render_success
      if skip_authorization? || can_authorize_response?
        redirect_or_render(authorize_response)
      elsif Doorkeeper.configuration.api_only
        render json: pre_auth
      else
        render :new
      end
    end

    def render_error
      pre_auth.error_response.raise_exception! if Doorkeeper.config.raise_on_errors?

      if Doorkeeper.configuration.redirect_on_errors? && pre_auth.error_response.redirectable?
        redirect_or_render(pre_auth.error_response)
      else
        render_error_response(pre_auth.error_response)
      end
    end

    def render_error_response(error_response)
      if Doorkeeper.configuration.api_only
        render json: error_response.body, status: error_response.status
      else
        render :error, locals: { error_response: error_response }, status: error_response.status
      end
    end

    # Refuses the request before resource owner authentication when the
    # client_id or redirect_uri is missing or invalid. Errors are rendered,
    # never redirected, regardless of `handle_auth_errors :redirect`: no
    # failure this check can produce leaves a redirect target worth trusting.
    # Either the client failed first, so the redirect URI was never reached,
    # or the redirect URI is itself the invalid one — and RFC 6749
    # Section 3.1.2.4 forbids redirecting the user-agent to an invalid
    # redirection URI.
    #
    # Host applications that need to refuse a client on their own terms (an
    # allow-list, a registry lookup) can override this and call +super+ first:
    #
    #   class AuthorizationsController < Doorkeeper::AuthorizationsController
    #     private
    #
    #     def validate_client
    #       super
    #       return if performed?
    #       return if MyRegistry.allowed?(client_pre_auth.client.application)
    #
    #       head :forbidden
    #     end
    #   end
    def validate_client
      return if client_pre_auth.client_valid?

      error_response = client_pre_auth.error_response
      error_response.raise_exception! if Doorkeeper.config.raise_on_errors?

      render_error_response(error_response)
    end

    # The pre-authentication view of the request. It carries no resource owner
    # (nobody is authenticated yet), so it is kept apart from #pre_auth:
    # owner-dependent validations (authorize_resource_owner_for_client) and the
    # views need the one built with current_resource_owner.
    def client_pre_auth
      @client_pre_auth ||= OAuth::PreAuthorization.new(Doorkeeper.configuration, pre_auth_params)
    end

    def can_authorize_response?
      Doorkeeper.config.custom_access_token_attributes.empty? && pre_auth.client.application.confidential? && matching_token?
    end

    # Active access token issued for the same client and resource owner with
    # the same set of the scopes exists?
    def matching_token?
      # We don't match tokens on the custom attributes here - we're in the pre-auth here,
      # so they haven't been supplied yet (there are no custom attributes to match on yet)
      @matching_token ||= Doorkeeper.config.access_token_model.matching_token_for(
        pre_auth.client,
        current_resource_owner,
        pre_auth.scopes,
      ) do |token|
        # RFC 8707: a token for a different audience must not satisfy the match.
        Doorkeeper.config.access_token_model.resource_indicators_match?(
          token, pre_auth.resource_indicators&.join(" ").presence,
        )
      end
    end

    def redirect_or_render(auth)
      if auth.redirectable?
        if Doorkeeper.configuration.api_only
          if pre_auth.form_post_response?
            render(
              json: { status: :post, redirect_uri: pre_auth.redirect_uri, body: auth.body },
              status: auth.status,
            )
          else
            render(
              json: { status: :redirect, redirect_uri: auth.redirect_uri },
              status: auth.status,
            )
          end
        elsif pre_auth.form_post_response?
          render :form_post, locals: { auth: auth }
        else
          redirect_to auth.redirect_uri, allow_other_host: true
        end
      else
        render json: auth.body, status: auth.status
      end
    end

    def pre_auth
      @pre_auth ||= OAuth::PreAuthorization.new(
        Doorkeeper.configuration,
        pre_auth_params,
        current_resource_owner,
      )
    end

    def pre_auth_params
      # RFC 8707: `resource` may appear as a single value (?resource=…) or as
      # a Rails-style array (?resource[]=…&resource[]=…). Both scalar and array
      # forms are permitted through strong parameters.
      #
      # NOTE: The RFC wire format uses repeated keys (?resource=…&resource=…),
      # but Rack collapses those into the last value. Clients targeting this
      # endpoint must use the resource[] bracket syntax for multiple values.
      params
        .slice(*pre_auth_param_fields, :resource)
        .permit(*pre_auth_param_fields, :resource, resource: [])
    end

    def pre_auth_param_fields
      @pre_auth_param_fields ||= custom_access_token_attributes + %i[
        client_id
        code_challenge
        code_challenge_method
        response_type
        response_mode
        redirect_uri
        scope
        state
      ]
    end

    def custom_access_token_attributes
      Doorkeeper.config.custom_access_token_attributes.map(&:to_sym)
    end

    def authorization
      @authorization ||= strategy.request
    end

    def strategy
      @strategy ||= server.authorization_request(pre_auth.response_type)
    end

    def authorize_response
      @authorize_response ||= begin
        unless pre_auth.authorizable?
          response = pre_auth.error_response
          response.raise_exception! if Doorkeeper.config.raise_on_errors?
          return response
        end

        context = build_context(pre_auth: pre_auth)
        before_successful_authorization(context)

        auth = strategy.authorize

        context = build_context(auth: auth)
        after_successful_authorization(context)

        auth
      end
    end

    def build_context(**attributes)
      Doorkeeper::OAuth::Hooks::Context.new(**attributes)
    end

    def before_successful_authorization(context = nil)
      Doorkeeper.config.before_successful_authorization.call(self, context)
    end

    def after_successful_authorization(context)
      Doorkeeper.config.after_successful_authorization.call(self, context)
    end
  end
end
