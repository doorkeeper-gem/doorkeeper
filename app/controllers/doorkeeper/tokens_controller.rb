class Doorkeeper::TokensController < Doorkeeper::ApplicationController
  def create
    response.headers.merge!({
      'Pragma'        => 'no-cache',
      'Cache-Control' => 'no-store',
    })
    if token.authorize
      render :json => token.authorization
    else
      render :json => token.error_response, :status => token.error_response.status
    end
  end

  def tokeninfo
    if doorkeeper_token && doorkeeper_token.valid? && !doorkeeper_token.expired? 
      render :json => doorkeeper_token, :status => :ok
    else
      render :json => { :error => 'invalid_token' }, :status => :unauthorized
    end 
  end

  private

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
