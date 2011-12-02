module AccessTokenRequestHelper
  def client_is_authorized(client, resource_owner)
    Factory(:access_token, :application => client, :resource_owner_id => resource_owner.id)
  end

  def token_endpoint_url(options = {})
    client_id     = options[:client_id]     ? options[:client_id]     : options[:client].uid
    client_secret = options[:client_secret] ? options[:client_secret] : options[:client].secret
    redirect_uri  = options[:redirect_uri]  ? options[:redirect_uri]  : options[:client].redirect_uri
    grant_type    = options[:grant_type] || "authorization_code"
    "/oauth/token?code=#{options[:code]}&client_id=#{client_id}&client_secret=#{client_secret}&redirect_uri=#{redirect_uri}&grant_type=#{grant_type}"
  end

  def with_access_token_header(token)
    page.driver.header 'Authorization', "Bearer #{token}"
  end

  def response_status_should(status)
    page.driver.response.status.to_i.should == status
  end

  def parsed_response
    JSON.parse(response.body)
  end
end
