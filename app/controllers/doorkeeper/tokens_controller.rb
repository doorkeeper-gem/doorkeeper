class Doorkeeper::TokensController < Doorkeeper::ApplicationController
  before_filter :cors_options_check
  after_filter :cors_set_access_control_headers

  def create
    response.headers.merge!({
      'Pragma'        => 'no-cache',
      'Cache-Control' => 'no-store',
    })
    if token.authorize
      render :json => token.authorization
    elsif request.method == 'OPTIONS'
      render :nothing => true
    else
      render :json => token.error_response, :status => token.error_response.status
    end
  end

  private

  def cors_set_access_control_headers
    response.headers.merge!({
      'Access-Control-Allow-Origin' => '*',
      'Access-Control-Allow-Methods' => 'POST, OPTIONS',
      'Access-Control-Max-Age' => '1728000'
    })
  end

  def cors_options_check
    if request.method == 'OPTIONS'
      response.headers.merge!({
        'Access-Control-Allow-Origin' => '*',
        'Access-Control-Allow-Methods' => 'POST, OPTIONS',
        'Access-Control-Allow-Headers' => 'Content-Type',
        'Access-Control-Max-Age' => '1728000'
      })
    end
  end

  def client
    @client ||= Doorkeeper::OAuth::Client.authenticate(credentials)
  end

  def credentials
    methods = Doorkeeper.configuration.client_credentials_methods
    @credentials ||= Doorkeeper::OAuth::Client::Credentials.from_request(request, *methods)
  end

  def token
    case params[:grant_type]
    when 'password'
      owner = resource_owner_from_credentials
      @token ||= Doorkeeper::OAuth::PasswordAccessTokenRequest.new(client, owner, params)
    when 'client_credentials'
      @token ||= Doorkeeper::OAuth::ClientCredentialsRequest.new(Doorkeeper.configuration, client, params)
    else
      @token ||= Doorkeeper::OAuth::AccessTokenRequest.new(client, params)
    end
  end
end
