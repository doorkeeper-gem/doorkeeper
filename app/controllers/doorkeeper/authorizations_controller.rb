class Doorkeeper::AuthorizationsController < Doorkeeper::ApplicationController
  before_filter :authenticate_resource_owner!

  def new
    if authorization.valid?
      if authorization.access_token_exists?
        auth = authorization.authorize
        if authorization.success_redirect_uri.present?
          redirect_to authorization.success_redirect_uri
        else
          redirect_to oauth_authorization_code_path(:code => auth.token)
        end
      end
    elsif authorization.redirect_on_error?
      redirect_to authorization.invalid_redirect_uri
    else
      @error = authorization.error_response
      render :error
    end
  rescue Doorkeeper::Errors::InvalidRequestStrategy
    error = Doorkeeper::OAuth::ErrorResponse.new :name => :unsupported_response_type
    to = Doorkeeper::OAuth::Authorization::URIBuilder.uri_with_query server.client_via_uid.redirect_uri, error.attributes
    redirect_to to
  rescue Doorkeeper::Errors::MissingRequestStrategy
    error = Doorkeeper::OAuth::ErrorResponse.new :name => :invalid_request
    to = Doorkeeper::OAuth::Authorization::URIBuilder.uri_with_query server.client_via_uid.redirect_uri, error.attributes
    redirect_to to
  end

  def show
  end

  def create
    if auth = authorization.authorize
      if authorization.success_redirect_uri.present?
        redirect_to authorization.success_redirect_uri
      else
        redirect_to oauth_authorization_code_path(:code => auth.token)
      end
    elsif authorization.redirect_on_error?
      redirect_to authorization.invalid_redirect_uri
    else
      @error = authorization.error_response
      render :error
    end
  end

  def destroy
    authorization.deny
    redirect_to authorization.invalid_redirect_uri
  end

private

  def authorization
    @authorization ||= strategy.request
  end

  def server
    @server ||= Doorkeeper::Server.new(self)
  end

  def strategy
    @strategy ||= server.request params[:response_type]
  end
end
