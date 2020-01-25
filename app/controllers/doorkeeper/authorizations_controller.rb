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
      redirect_or_render authorize_response
    end

    def destroy
      redirect_or_render authorization.deny
    end

    private

    def render_success
      if skip_authorization? || matching_token?
        redirect_or_render authorize_response
      elsif Doorkeeper.configuration.api_only
        render json: pre_auth
      else
        render :new
      end
    end

    def render_error
      if Doorkeeper.configuration.api_only
        render json: pre_auth.error_response.body,
               status: :bad_request
      else
        render :error
      end
    end

    def matching_token?
      AccessToken.matching_token_for(
        pre_auth.client,
        current_resource_owner,
        pre_auth.scopes,
      )
    end

    def redirect_or_render(auth)
      if auth.redirectable?
        if Doorkeeper.configuration.api_only
          render(
            json: { status: :redirect, redirect_uri: auth.redirect_uri },
            status: auth.status,
          )
        else
          redirect_to auth.redirect_uri
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
      %i[client_id response_type redirect_uri scope state code_challenge
         code_challenge_method]
    end

    def authorization
      @authorization ||= strategy.request
    end

    def strategy
      @strategy ||= server.authorization_request pre_auth.response_type
    end

    def authorize_response
      @authorize_response ||= begin
        return pre_auth.error_response unless pre_auth.authorizable?

        before_successful_authorization
        auth = strategy.authorize
        after_successful_authorization
        auth
      end
    end

    def after_successful_authorization
      Doorkeeper.configuration.after_successful_authorization.call(self)
    end

    def before_successful_authorization
      Doorkeeper.configuration.before_successful_authorization.call(self)
    end
  end
end
