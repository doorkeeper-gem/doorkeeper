class Doorkeeper::TokensController < Doorkeeper::ApplicationController
  def create
    response.headers.merge!({
      'Pragma'        => 'no-cache',
      'Cache-Control' => 'no-store',
    })
    if token.authorize
      render :json => token.authorization
    else
      render :json => token.error_response, :status => :unauthorized
    end
  end

  private

  def client
    @client ||= Doorkeeper::OAuth::Client.authenticate(credentials)
  end

  def credentials
    @credentials ||= Doorkeeper::OAuth::Client::Credentials.from_request(request)
  end

  def token
    if params[:grant_type] == 'password'
      owner = resource_owner_from_credentials
      @token ||= Doorkeeper::OAuth::PasswordAccessTokenRequest.new(client, owner, params)
    else
      @token ||= Doorkeeper::OAuth::AccessTokenRequest.new(client, params)
    end
  end
end
