# frozen_string_literal: true

module Doorkeeper
  class AuthorizationsController < Doorkeeper::ApplicationController
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
      elsif Doorkeeper.configuration.api_only
        render json: pre_auth.error_response.body, status: pre_auth.error_response.status
      else
        render :error, locals: { error_response: pre_auth.error_response }, status: pre_auth.error_response.status
      end
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
      )
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
      params.slice(*pre_auth_param_fields).permit(*pre_auth_param_fields)
    end

    def pre_auth_param_fields
      custom_access_token_attributes + %i[
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
        return pre_auth.error_response unless pre_auth.authorizable?

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
